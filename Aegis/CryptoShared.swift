//
//  CryptoShared.swift
//  Aegis
//
//  Created by Khalid Alkhaldi on 10/20/25.
//

import Foundation
import CryptoKit
import Security

// MARK: - Errors

enum CryptoErr: Error, LocalizedError {
    case keyGeneration(String)
    case keychain(String)
    case sign(String)
    case verify(String)
    case encrypt(String)
    case decrypt(String)
    case badJSON
    case badPEM
    
    var errorDescription: String? {
        switch self {
        case .keyGeneration(let m): return "Key generation failed. \(m)"
        case .keychain(let m):     return "Keychain operation failed. \(m)"
        case .sign(let m):         return "Signing failed. \(m)"
        case .verify(let m):       return "Signature verification failed. \(m)"
        case .encrypt(let m):      return "Encryption failed. \(m)"
        case .decrypt(let m):      return "Decryption failed. \(m)"
        case .badJSON:             return "Invalid JSON format."
        case .badPEM:              return "Invalid PEM key format."
        }
    }
}

// MARK: - Helpers

@inline(__always)
private func cfErrorMessage(_ err: CFError?) -> String {
    guard let e = err else { return "Unknown CFError" }
    return (e as Error).localizedDescription
}

@inline(__always)
private func osStatusDescription(_ status: OSStatus) -> String {
    (SecCopyErrorMessageString(status, nil) as String?) ?? "OSStatus \(status)"
}

private extension Data {
    static func + (lhs: Data, rhs: Data) -> Data {
        var d = lhs
        d.append(rhs)
        return d
    }
}

// MARK: - PEM helpers (encode/decode, PKCS#1 → SPKI)

private func pemWrap(der: Data, header: String) -> Data {
    let b64 = der.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
    let pem = "-----BEGIN \(header)-----\n\(b64)\n-----END \(header)-----\n"
    return Data(pem.utf8)
}

private func derLength(_ n: Int) -> [UInt8] {
    precondition(n >= 0)
    if n < 0x80 { return [UInt8(n)] }
    var bytes: [UInt8] = []
    var v = n
    while v > 0 { bytes.insert(UInt8(v & 0xFF), at: 0); v >>= 8 }
    return [0x80 | UInt8(bytes.count)] + bytes
}

private func cleanBase64(from s: String) -> Data? {
    let filtered = s.unicodeScalars.filter {
        ("A"..."Z").contains($0) || ("a"..."z").contains($0) ||
        ("0"..."9").contains($0) || $0 == "+" || $0 == "/" || $0 == "="
    }
    return Data(base64Encoded: String(String.UnicodeScalarView(filtered)))
}

private func stripPEMBlock(_ pemData: Data, header: String) throws -> Data {
    guard var s = String(data: pemData, encoding: .utf8) else { throw CryptoErr.badPEM }
    s = s.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    guard let begin = s.range(of: "-----BEGIN \(header)-----"),
          let end   = s.range(of: "-----END \(header)-----") else { throw CryptoErr.badPEM }
    let inner = String(s[begin.upperBound..<end.lowerBound])
    guard let der = cleanBase64(from: inner) else { throw CryptoErr.badPEM }
    return der
}

// Wrap PKCS#1 RSAPublicKey DER inside SPKI DER
private func wrapRSAPKCS1toSPKI(_ pkcs1DER: Data) -> Data {
    let oid: [UInt8]  = [0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01]
    let null_: [UInt8] = [0x05, 0x00]
    let algContent = oid + null_
    let algSeq     = [0x30] + derLength(algContent.count) + algContent
    let bitContent = [UInt8(0x00)] + [UInt8](pkcs1DER)
    let bitString  = [0x03] + derLength(bitContent.count) + bitContent
    let spkiContent = algSeq + bitString
    return Data([0x30] + derLength(spkiContent.count) + spkiContent)
}

// MARK: - Keychain (private key only; auto-generate)

struct RSAKeys {
    static let tagPriv = "com.Aegis.rsa4096.priv"
    static let privLabel = "Aegis RSA-4096 Private Key"
    static let comment   = "Created by Aegis. RSA-OAEP-256 + RSA-PSS-256."
    
    static func ensureKeypair() throws {
        if try loadPrivate() != nil { return }
        
        let privAttrs: [String: Any] = [
            kSecAttrIsPermanent as String: true,
            kSecAttrApplicationTag as String: tagPriv.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrLabel as String: privLabel,
            kSecAttrComment as String: comment
        ]
        
        let params: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 4096,
            kSecPrivateKeyAttrs as String: privAttrs
        ]
        
        var err: Unmanaged<CFError>?
        guard SecKeyCreateRandomKey(params as CFDictionary, &err) != nil else {
            throw CryptoErr.keyGeneration(cfErrorMessage(err?.takeRetainedValue()))
        }
    }
    
    static func loadPrivate() throws -> SecKey? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrApplicationTag as String: tagPriv.data(using: .utf8)!,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let st = SecItemCopyMatching(q as CFDictionary, &item)
        if st == errSecItemNotFound { return nil }
        guard st == errSecSuccess else { throw CryptoErr.keychain(osStatusDescription(st)) }
        return (item as! SecKey)
    }
    
    static func currentPublicKey() throws -> SecKey {
        guard let priv = try loadPrivate() else { throw CryptoErr.keychain("No private key found.") }
        guard let pub  = SecKeyCopyPublicKey(priv) else { throw CryptoErr.keychain("Failed to derive public key.") }
        return pub
    }
    
    static func publicKeyDER() throws -> Data {
        let pub = try currentPublicKey()
        var e: Unmanaged<CFError>?
        guard let der = SecKeyCopyExternalRepresentation(pub, &e) as Data? else {
            throw CryptoErr.keychain("Exporting public key failed: \(cfErrorMessage(e?.takeRetainedValue()))")
        }
        return der
    }
    
    static func exportPublicPEM() throws -> Data {
        pemWrap(der: try publicKeyDER(), header: "PUBLIC KEY")
    }
    
    static func pubFingerprintSHA256() throws -> String {
        let der = try publicKeyDER()
        return Data(SHA256.hash(data: der)).base64EncodedString()
    }
}

// MARK: - PEM → SecKey (SPKI / PKCS#1 / CERT)

func pemUnwrapPublicKey(_ pemData: Data) throws -> SecKey {
    guard var pem = String(data: pemData, encoding: .utf8) else { throw CryptoErr.badPEM }
    pem = pem.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    
    if pem.contains("-----BEGIN CERTIFICATE-----") {
        let certDER = try stripPEMBlock(pemData, header: "CERTIFICATE")
        guard let cert = SecCertificateCreateWithData(nil, certDER as CFData) else { throw CryptoErr.badPEM }
        if #available(macOS 10.14, *), let key = SecCertificateCopyKey(cert) { return key }
        throw CryptoErr.badPEM
    }
    
    if pem.contains("-----BEGIN PUBLIC KEY-----") {
        let spkiDER = try stripPEMBlock(pemData, header: "PUBLIC KEY")
        let attrs: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic
        ]
        var err: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(spkiDER as CFData, attrs as CFDictionary, &err) else {
            throw CryptoErr.badPEM
        }
        return key
    }
    
    if pem.contains("-----BEGIN RSA PUBLIC KEY-----") {
        let pkcs1DER = try stripPEMBlock(pemData, header: "RSA PUBLIC KEY")
        let spkiDER  = wrapRSAPKCS1toSPKI(pkcs1DER)
        let attrs: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic
        ]
        var err: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(spkiDER as CFData, attrs as CFDictionary, &err) else {
            throw CryptoErr.badPEM
        }
        return key
    }
    
    throw CryptoErr.badPEM
}

func pubFingerprintPEMData(_ pem: Data) throws -> String {
    let key = try pemUnwrapPublicKey(pem)
    var e: Unmanaged<CFError>?
    guard let der = SecKeyCopyExternalRepresentation(key, &e) as Data? else {
        throw CryptoErr.keychain("Could not export supplied public key: \(cfErrorMessage(e?.takeRetainedValue()))")
    }
    return Data(SHA256.hash(data: der)).base64EncodedString()
}

// MARK: - Hybrid V2 (embed sender pub; sign over it)

struct HybridBlobV2: Codable {
    let alg: String
    let enc_key: String
    let nonce: String
    let ciphertext: String
    let signature: String
    let sender_pub: String  // PEM (SPKI)
    let sender_fp: String   // Base64(SHA256(SPKI DER))
}

private func myPublicPEMAndFingerprint() throws -> (pem: String, der: Data, fpB64: String) {
    let der = try RSAKeys.publicKeyDER()
    let pemData = pemWrap(der: der, header: "PUBLIC KEY")
    let fp = Data(SHA256.hash(data: der)).base64EncodedString()
    guard let pem = String(data: pemData, encoding: .utf8) else { throw CryptoErr.keychain("PEM encode failed") }
    return (pem, der, fp)
}

func encryptHybridV2(plaintext: Data, senderPriv: SecKey, recipientPub: SecKey) throws -> String {
    // AES-GCM
    let aesKey = SymmetricKey(size: .bits256)
    let sealed = try AES.GCM.seal(plaintext, using: aesKey)
    let nonceData = sealed.nonce.withUnsafeBytes { Data($0) }
    guard let combined = sealed.combined else { throw CryptoErr.encrypt("Combined GCM data missing.") }
    
    // Wrap AES key with RSA-OAEP-256
    let rsaEnc = SecKeyAlgorithm.rsaEncryptionOAEPSHA256
    guard SecKeyIsAlgorithmSupported(recipientPub, .encrypt, rsaEnc) else {
        throw CryptoErr.encrypt("Recipient key does not support RSA-OAEP-256.")
    }
    var err: Unmanaged<CFError>?
    let rawKey = Data(aesKey.withUnsafeBytes { Data($0) })
    guard let encKey = SecKeyCreateEncryptedData(recipientPub, rsaEnc, rawKey as CFData, &err) as Data? else {
        throw CryptoErr.encrypt(cfErrorMessage(err?.takeRetainedValue()))
    }
    
    // Include my public key (PEM + DER + fingerprint)
    let (myPEM, myDER, myFP) = try myPublicPEMAndFingerprint()
    
    // Sign (nonce || combined || myDER)
    let rsaPSS = SecKeyAlgorithm.rsaSignatureMessagePSSSHA256
    guard SecKeyIsAlgorithmSupported(senderPriv, .sign, rsaPSS) else {
        throw CryptoErr.sign("Sender key does not support RSA-PSS-256.")
    }
    let toSign = nonceData + combined + myDER
    guard let sig = SecKeyCreateSignature(senderPriv, rsaPSS, toSign as CFData, &err) as Data? else {
        throw CryptoErr.sign(cfErrorMessage(err?.takeRetainedValue()))
    }
    
    let blob = HybridBlobV2(
        alg: "RSA-OAEP-256+AES-GCM+RSA-PSS-256",
        enc_key: encKey.base64EncodedString(),
        nonce: nonceData.base64EncodedString(),
        ciphertext: combined.base64EncodedString(),
        signature: sig.base64EncodedString(),
        sender_pub: myPEM,
        sender_fp: myFP
    )
    let json = try JSONEncoder().encode(blob)
    return String(data: json, encoding: .utf8)!
}

struct DecryptResult {
    let plaintext: Data
    let senderPub: SecKey
    let senderFingerprint: String
}

func decryptHybridV2(json: String, recipientPriv: SecKey) throws -> DecryptResult {
    guard let data = json.data(using: .utf8) else { throw CryptoErr.badJSON }
    let blob = try JSONDecoder().decode(HybridBlobV2.self, from: data)
    
    guard let encKey = Data(base64Encoded: blob.enc_key),
          let nonce = Data(base64Encoded: blob.nonce),
          let combined = Data(base64Encoded: blob.ciphertext),
          let sig = Data(base64Encoded: blob.signature) else {
        throw CryptoErr.badJSON
    }
    
    // Build sender public key from embedded PEM
    let senderPub = try pemUnwrapPublicKey(Data(blob.sender_pub.utf8))
    
    // Export sender DER and verify signature
    var err: Unmanaged<CFError>?
    guard let senderDER = SecKeyCopyExternalRepresentation(senderPub, &err) as Data? else {
        throw CryptoErr.verify("Sender pub export failed: \(cfErrorMessage(err?.takeRetainedValue()))")
    }
    let rsaPSS = SecKeyAlgorithm.rsaSignatureMessagePSSSHA256
    let signed = nonce + combined + senderDER
    guard SecKeyVerifySignature(senderPub, rsaPSS, signed as CFData, sig as CFData, &err) else {
        throw CryptoErr.verify(cfErrorMessage(err?.takeRetainedValue()))
    }
    
    // Unwrap AES key and decrypt
    let rsaDec = SecKeyAlgorithm.rsaEncryptionOAEPSHA256
    guard SecKeyIsAlgorithmSupported(recipientPriv, .decrypt, rsaDec) else {
        throw CryptoErr.decrypt("Recipient key does not support RSA-OAEP-256.")
    }
    guard let rawKey = SecKeyCreateDecryptedData(recipientPriv, rsaDec, encKey as CFData, &err) as Data? else {
        throw CryptoErr.decrypt(cfErrorMessage(err?.takeRetainedValue()))
    }
    let sym = SymmetricKey(data: rawKey)
    
    let box = try AES.GCM.SealedBox(combined: combined)
    let pt = try AES.GCM.open(box, using: sym)
    
    let computedFP = Data(SHA256.hash(data: senderDER)).base64EncodedString()
    return DecryptResult(plaintext: pt, senderPub: senderPub, senderFingerprint: computedFP)
}
