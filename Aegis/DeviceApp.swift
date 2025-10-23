//
//  DeviceApp.swift
//  Aegis
//
//  Created by Khalid Alkhaldi on 10/20/25.

import SwiftUI
import AppKit
import CryptoKit
import Security

@main
struct DeviceAApp: App {
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 980, minHeight: 720)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Aegis") {
                    let info = Bundle.main
                    let name    = (info.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Aegis") as NSString
                    let version = (info.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0") as NSString
                    let build   = (info.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1") as NSString
                    
                    let credits = NSAttributedString(
                        string: "A modern end-to-end encryption messenges\n\t\t© 2025 Khalid Alkhaldi.\n\t\t\tMade with ❤️",
                        attributes: [.font: NSFont.systemFont(ofSize: 12)]
                    )
                    
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: name,
                        .applicationVersion: version,       // shown under app name
                        .version: "Build \(build)" as NSString, // optional extra line
                        .credits: credits                   // MUST be NSAttributedString
                    ])
                }
            }
        }
    }
}

struct ContentView: View {
    // Learned reply-to key (from last Decrypt). If nil, Encrypt falls back to self-encrypt.
    @State private var replyKey: SecKey? = nil
    @State private var replyFP: String = "none"
    
    // UI state
    @State private var plaintext: String = ""
    @State private var envelopeB64: String = ""     // Base64-wrapped JSON (read-only)
    @State private var incoming: String = ""        // Accepts Base64 or raw JSON
    @State private var decrypted: String = ""
    
    // Alerts & progress
    @State private var alert: AlertInfo?
    @State private var isWorking = false
    @State private var progress: Double = 0.0
    @State private var statusText: String = ""
    @State private var cancelRequested = false
    @State private var encryptTask: Task<Void, Never>? = nil
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color.accentColor.opacity(0.15), Color.clear],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                // MARK: Header
                header
                
                // MARK: Toolbar
                toolbar
                
                Divider()
                
                // MARK: Main content
                ScrollView {
                    VStack(spacing: 18) {
                        HStack(alignment: .top, spacing: 18) {
                            composeCard
                            decryptCard
                        }
                        .padding(.horizontal, 20)
                        
                        outputCard
                            .padding(.horizontal, 20)
                        
                        decryptedCard
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                    }
                    .padding(.top, 16)
                }
            }
            .blur(radius: isWorking ? 1.0 : 0)
            
            // MARK: Progress overlay
            if isWorking { progressOverlay }
        }
        .alert(item: $alert) { info in
            Alert(title: Text(info.title),
                  message: Text(info.message),
                  dismissButton: .default(Text("OK")))
        }
        .onDisappear { encryptTask?.cancel() }
        .onAppear { _ = AppPaths.appSupportDir }
    }
    
    // MARK: Header
    
    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    LinearGradient(colors: [
                        Color.accentColor.opacity(0.35),
                        Color.clear
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(height: 120)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 64, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.trailing, 24)
                        .padding(.top, 10)
                }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Aegis v1.0.0")
                    .font(.system(size: 34, weight: .bold))
                HStack(spacing: 10) {
                    pill(
                        icon: "person.crop.circle.badge.checkmark",
                        text: "Reply-to: \(replyFP)",
                        tint: .green
                    )
                }
            }
            .padding(.leading, 24)
            .padding(.bottom, 14)
        }
    }
    
    // MARK: Toolbar
    
    private var toolbar: some View {
        HStack(spacing: 12) {
            Button {
                doEncrypt()
            } label: {
                labelPrimary(title: "Encrypt & Copy", icon: "lock.fill")
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(isWorking)
            
            Button {
                doDecrypt()
            } label: {
                labelSecondary(title: "Decrypt", icon: "key.fill")
            }
            .keyboardShortcut("d", modifiers: [.command])
            .disabled(isWorking)
            
            Spacer()
            
            Text("Developed by Khalid Alkhaldi")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.trailing, 12)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.thinMaterial)
    }
    
    // MARK: Cards
    
    
    private var composeCard: some View {
        card(title: "Compose",
             subtitle: "Write your message",
             icon: "square.and.pencil",
             tint: .blue) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Spacer()
                    Button {
                        plaintext.removeAll()
                    } label: {
                        Label("Clear", systemImage: "xmark.circle.fill")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
                
                AutoScrollingTextEditor(text: $plaintext, isEditable: true)
                    .frame(height: 180)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(nsColor: .textBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                            )
                    )
            }
        }
             .frame(minWidth: 460)
    }
    
    
    private var decryptCard: some View {
        card(title: "Decrypt",
             subtitle: "Paste Base64 envelope or raw JSON",
             icon: "tray.and.arrow.down.fill",
             tint: .purple) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Spacer()
                    Button {
                        incoming.removeAll()
                    } label: {
                        Label("Clear", systemImage: "xmark.circle.fill")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
                
                AutoScrollingTextEditor(text: $incoming, isEditable: true)
                    .frame(height: 180)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(nsColor: .textBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                            )
                    )
            }
        }
             .frame(minWidth: 460)
    }
    
    private var outputCard: some View {
        card(title: "Encrypted Envelope", subtitle: "Base64-wrapped JSON (read-only)", icon: "doc.on.doc.fill", tint: .teal) {
            VStack(alignment: .leading, spacing: 10) {
                ScrollView {
                    TextEditor(text: $envelopeB64)
                        .textEditorStyleFancy(readOnly: true)
                        .frame(minHeight: 140)
                        .disabled(true)               // read-only
                        .textSelection(.enabled)
                }
                .frame(height: 140) // limit ScrollView height
                HStack {
                    Spacer()
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(envelopeB64, forType: .string)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
    
    private var decryptedCard: some View {
        card(title: "Decrypted Plaintext", subtitle: "Verified & opened", icon: "text.alignleft", tint: .green) {
            VStack(alignment: .leading, spacing: 10) {
                ScrollView {
                    TextEditor(text: $decrypted)
                        .textEditorStyleFancy(readOnly: true)
                        .frame(minHeight: 120)
                        .disabled(true)
                        .textSelection(.enabled)
                }
                .frame(height: 120) // limit ScrollView height
            }
        }
    }
    
    // MARK: Progress overlay
    
    private var progressOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("Encrypting…")
                    .font(.headline)
                ProgressView(value: progress)
                    .frame(width: 360)
                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 420)
                    .multilineTextAlignment(.center)
                Button("Cancel") {
                    cancelRequested = true
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(22)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 12)
        }
    }
    
    // MARK: Actions
    
    func doEncrypt() {
        encryptTask?.cancel()
        encryptTask = Task {
            await MainActor.run { startProgress() }
            do {
                try RSAKeys.ensureKeypair()
                try await step(0.10, "Ensuring local keypair…")
                
                guard let myPriv = try RSAKeys.loadPrivate() else {
                    throw CryptoErr.keychain("Private key not found.")
                }
                
                let recipient: SecKey
                let toFP: String
                if let k = replyKey, let der = exportDER(from: k) {
                    recipient = k
                    toFP = Data(SHA256.hash(data: der)).base64EncodedString()
                    try await step(0.20, "Using learned reply-to key…")
                } else {
                    let myPub = try RSAKeys.currentPublicKey()
                    recipient = myPub
                    let der = try RSAKeys.publicKeyDER()
                    toFP = Data(SHA256.hash(data: der)).base64EncodedString()
                    try await step(0.20, "No recipient yet — encrypting to self…")
                }
                
                let data = Data(plaintext.utf8)
                try await step(0.35, "Preparing plaintext…")
                try await step(0.70, "Sealing with AES-GCM, wrapping key, signing…")
                
                let json = try encryptHybridV2(plaintext: data, senderPriv: myPriv, recipientPub: recipient)
                let b64 = Data(json.utf8).base64EncodedString()
                
                await MainActor.run {
                    envelopeB64 = b64
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(b64, forType: .string)
                    replyFP = toFP
                }
                try await step(0.95, "Copying envelope to clipboard…")
                
                await MainActor.run {
                    alert = AlertInfo(title: "Encrypted", message: "Base64 envelope copied.\nTo: \(toFP)")
                }
            } catch is CancellationError {
                await MainActor.run {
                    alert = AlertInfo(title: "Canceled", message: "Encryption canceled.")
                }
            } catch {
                await MainActor.run {
                    alert = AlertInfo(title: "Encrypt Error", message: error.localizedDescription)
                    AppPaths.log("Encrypt error: \(error)")
                }
            }
            await MainActor.run { finishProgress() }
        }
    }
    
    func doDecrypt() {
        DispatchQueue.main.async {
            do {
                try RSAKeys.ensureKeypair()
                guard let myPriv = try RSAKeys.loadPrivate() else {
                    throw CryptoErr.keychain("Private key not found.")
                }
                
                // Accept Base64 or raw JSON
                let raw = incoming.trimmingCharacters(in: .whitespacesAndNewlines)
                let jsonString: String
                if let decoded = Data(base64Encoded: raw),
                   let s = String(data: decoded, encoding: .utf8) {
                    jsonString = s
                } else {
                    jsonString = raw
                }
                
                let result = try decryptHybridV2(json: jsonString, recipientPriv: myPriv)
                decrypted = String(data: result.plaintext, encoding: .utf8) ?? String(describing: result.plaintext)
                
                // learn sender for replies
                replyKey = result.senderPub
                replyFP  = result.senderFingerprint
                
                alert = AlertInfo(title: "Decrypted",
                                  message: "Signature verified.\nReply-to learned: \(replyFP)")
            } catch {
                alert = AlertInfo(title: "Decrypt/Verify Error", message: error.localizedDescription)
                AppPaths.log("Decrypt error: \(error)")
            }
        }
    }
    
    // MARK: Progress helpers
    
    @MainActor private func startProgress() {
        isWorking = true
        progress = 0
        statusText = "Starting…"
        cancelRequested = false
    }
    
    @MainActor private func step(_ value: Double, _ text: String) async throws {
        if Task.isCancelled || cancelRequested { throw CancellationError() }
        progress = value
        statusText = text
        try? await Task.sleep(nanoseconds: 70_000_000) // ~70ms
    }
    
    @MainActor private func finishProgress() {
        isWorking = false
        progress = 1.0
        statusText = ""
        cancelRequested = false
    }
    
    // MARK: Helpers
    
    private func exportDER(from pub: SecKey) -> Data? {
        var e: Unmanaged<CFError>?
        return SecKeyCopyExternalRepresentation(pub, &e) as Data?
    }
    
    private func pill(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(text)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.footnote.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.12), in: Capsule())
        .overlay(Capsule().stroke(tint.opacity(0.35), lineWidth: 1))
        .foregroundStyle(tint)
    }
    
    private func labelPrimary(title: String, icon: String) -> some View {
        Label {
            Text(title).fontWeight(.semibold)
        } icon: {
            Image(systemName: icon)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.accentColor, in: Capsule())
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
    }
    
    private func labelSecondary(title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
            .foregroundStyle(.primary)
    }
    
    private func card<T: View>(title: String, subtitle: String, icon: String, tint: Color, @ViewBuilder content: () -> T) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(tint.opacity(0.12))
                    Image(systemName: icon)
                        .foregroundStyle(tint)
                }
                .frame(width: 30, height: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            content()
        }
        .padding(14)
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
    }
}

// MARK: - Fancy TextEditor style

fileprivate extension View {
    func textEditorStyleFancy(readOnly: Bool = false) -> some View {
        self
            .font(.system(.body, design: .monospaced))
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
                    )
            )
            .overlay(alignment: .topTrailing) {
                if readOnly {
                    Text("READ-ONLY")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.gray.opacity(0.15), in: Capsule())
                        .padding(8)
                }
            }
    }
}

struct AlertInfo: Identifiable {
    var id = UUID()
    let title: String
    let message: String
}



