# 🔒 Aegis — Hybrid RSA/AES Secure Messages (macOS)

<!-- <img style=" display: block; margin-left: auto;margin-right: auto;" alt="1" src="/assets/Device.png" width="48" /> -->
<div align="center">

  ![Aegis](/assets/Device120.png)
  
</div>


<p align="center">
  <a href="https://github.com/khalidt/Aegis/actions/workflows/ci.yml">
    <img src="https://github.com/khalidt/Aegis/actions/workflows/ci.yml/badge.svg" alt="Build Status">
  </a>
  <a href="https://github.com/khalidt/Aegis/releases">
    <img src="https://img.shields.io/github/v/release/khalidt/Aegis?include_prereleases&sort=semver" alt="Latest Release">
  </a>
  <img src="https://img.shields.io/github/downloads/khalidt/Aegis/total" alt="Downloads">
  <a href="https://github.com/khalidt/Aegis/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/khalidt/Aegis" alt="License">
  </a>
  <img src="https://img.shields.io/badge/platform-macOS-lightgrey?logo=apple" alt="Platform">
</p>

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
- 💬 **Clean SwiftUI interface** only two buttons: *Encrypt* and *Decrypt*  
- 💾 **Local key management** no servers, no data collection  

---
## 📦 Installation

### 🍺 Option 1: Install via Homebrew *(recommended)*

You can install **Aegis** directly from your terminal using [Homebrew](https://brew.sh):

```bash
brew tap khalidt/aegis
brew install --cask aegis
```

Homebrew will automatically download, verify, and place **Aegis.app** in your `/Applications` folder.

> 🛡️ First launch and macOS Security Note:
Since Aegis is distributed outside the Mac App Store, macOS Gatekeeper may display a warning the first time you open it.
Just go to System Settings → Privacy & Security → Allow Anyway, or right-click → Open to trust the app.

To update later:

```bash
brew upgrade --cask aegis
```

To uninstall completely:

```bash
brew uninstall --cask aegis
```
---

### 💾 Option 2: Download manually

Download the latest version of **Aegis** from the [Releases page](https://github.com/khalidt/Aegis/releases):

1. Download the latest **Aegis-vX.X.X-app.zip** or **Aegis-vX.X.X.dmg** file.  
2. Unzip it, you’ll see **Aegis.app**.  
3. Drag it into your **Applications** folder.

---

### 🧑‍💻 Option 3: Build from source in Xcode

If you’d like to build **Aegis** yourself:

```bash
git clone https://github.com/khalidt/Aegis.git
cd Aegis
open Aegis.xcodeproj
```

In **Xcode**:
1. Open `Aegis.xcodeproj` in **Xcode** (macOS 15).
2. Select the **Device** scheme.
3. Choose target “Any Mac (Apple Silicon, Intel)”.
4. Build and run (`⌘R`). (Go to **Product → Build** or **Product → Run**.)

Or build via Terminal:

```bash
xcodebuild -project Aegis.xcodeproj \
           -scheme Device \
           -configuration Release \
           -destination 'platform=macOS' \
           build
```

Your compiled app will appear under:
```
~/Library/Developer/Xcode/DerivedData/.../Build/Products/Release/Aegis.app
```

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
- **macOS 15+** : native UI

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

    Aegis is a modern macOS desktop application that provides secure end-to-end message encryption 
    using a hybrid RSA-AES design.
    Copyright (C) 2025 Khalid Alkhaldi (k.t.alkhaldi@gmail.com)

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

---


### ❤️ Enjoy!

If you encounter issues, please open a [GitHub Issue](https://github.com/khalidt/Aegis/issues) with details or screenshots.
