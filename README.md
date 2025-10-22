# 🔒 Aegis — Hybrid RSA/AES Secure Messages (macOS)

**Aegis** is a modern macOS desktop application that provides secure end-to-end message encryption using a hybrid RSA-AES design.   It combines the speed of symmetric AES encryption with the robust key exchange and digital signature capabilities of RSA.

<table>
  <tr>
    <td><img width="1092" height="1100" alt="1" src="https://github.com/user-attachments/assets/c4f1bc54-294c-4dcd-9994-90bd45e7cf9f" />
    <td><img width="1092" height="1100" alt="2" src="https://github.com/user-attachments/assets/fb47a519-815e-4ba2-a788-33cbc537ead0" />
    <td><img width="1092" height="1100" alt="3" src="https://github.com/user-attachments/assets/62ddb9c7-a857-4a2e-9d48-e2997f778ad3" />
  </tr>
</table>

---

## ✨ Features

- 🧠 **Automatic key generation and storage** using the macOS Keychain  
- 🔐 **Hybrid encryption** (AES-GCM + RSA-OAEP)  
- 🖋️ **Digital signatures** with RSA-PSS for message integrity  
- 📎 **Base64-encoded JSON envelope** for easy sharing  
- 💬 **Clean SwiftUI interface** — only two buttons: *Encrypt* and *Decrypt*  
- 💾 **Local key management** — no servers, no data collection  

---

## 🧩 How It Works

### Encryption
1. A random 256-bit AES key is generated.
2. The plaintext is encrypted using **AES-GCM**.
3. The AES key is encrypted using **RSA-OAEP** with the recipient’s public key.
4. The ciphertext is signed using **RSA-PSS** with the sender’s private key.
5. The resulting Base64 JSON envelope is ready to share.

### Decryption
1. The recipient decrypts the AES key with their RSA private key.
2. The AES-GCM ciphertext is decrypted to recover the plaintext.
3. The sender’s signature is verified for authenticity.

---

## 🧮 Algorithm Summary

| Purpose | Algorithm |
|----------|------------|
| Key generation | RSA-4096 |
| Symmetric encryption | AES-256-GCM |
| Asymmetric wrapping | RSA-OAEP-SHA256 |
| Digital signature | RSA-PSS-SHA256 |
| Key fingerprint | SHA-256 |

---

## 🧱 Architecture

- **Swift 5 + SwiftUI**
- **CryptoKit** : for AES-GCM encryption
- **Security framework** : for RSA keypair management and signing
- **AppKit** : for Keychain access and About panel
- **macOS 12+** : native UI, backward compatible to macOS 11 with minimal adjustments

---

## 🖥️ Building in Xcode

1. Open `Aegis.xcodeproj` in **Xcode** (macOS 12 or newer).
2. In *Signing & Capabilities*, select your Team and enable **Hardened Runtime** or sign to be run locally.
3. Choose target “Any Mac (Apple Silicon, Intel)”.
4. Build and run (`⌘R`).

---

## 🗝️ Security Model

- Private keys are generated and stored inside the **macOS Keychain**.
- AES keys are ephemeral, generated per message and never reused.
- Signatures verify both message integrity and sender authenticity.
- The app does **not** connect to any external server or API.

---

## 🧾 Example of Decrypted Envelope (message)

```json
{
  "alg": "RSA-OAEP-256 + AES-GCM + RSA-PSS-256",
  "nonce": "a1b2c3d4e5f6g7h8",
  "enc_key": "Base64(...)",
  "ciphertext": "Base64(...)",
  "signature": "Base64(...)"
}

```

## 📜 License

GPLv3 License © 2025 — Khalid Alkhaldi
See LICENSE for details.

---

