import Foundation
import CryptoKit

// MARK: - SharingError

public enum SharingError: Error, LocalizedError, Sendable {
    case privacyModeBlocked
    case encryptionFailed(String)
    case storageBucketUnreachable
    case uploadFailed(retryCount: Int)
    case offlineMode

    public var errorDescription: String? {
        switch self {
        case .privacyModeBlocked:
            return "Sharing is blocked: privacy mode is set to local-only."
        case .encryptionFailed(let detail):
            return "Encryption failed: \(detail)"
        case .storageBucketUnreachable:
            return "The storage bucket is unreachable. Check your network connection."
        case .uploadFailed(let retryCount):
            return "Upload failed after \(retryCount) retries."
        case .offlineMode:
            return "Cannot upload: device is offline."
        }
    }
}

// MARK: - EncryptionService

/// Pure-static, Sendable namespace for AES-GCM encryption using CryptoKit.
/// Wire format: [12-byte nonce][ciphertext][16-byte GCM tag]
public enum EncryptionService: Sendable {

    // MARK: - Constants

    private static let saltData = Data("SnapForge-HKDF-Salt-v1".utf8)
    private static let infoData = Data("SnapForge-AES256GCM-Key".utf8)

    // MARK: - Public API

    /// Encrypts `data` using a key derived from `passphrase` via HKDF-SHA256.
    /// Returns bytes in the layout: [12-byte nonce | ciphertext | 16-byte tag].
    public static func encrypt(data: Data, passphrase: String) throws -> Data {
        let key = try deriveKey(from: passphrase)

        let sealedBox: AES.GCM.SealedBox
        do {
            sealedBox = try AES.GCM.seal(data, using: key)
        } catch {
            throw SharingError.encryptionFailed(error.localizedDescription)
        }

        // Combine nonce + ciphertext + tag into a single blob.
        var combined = Data()
        combined.append(contentsOf: sealedBox.nonce)
        combined.append(sealedBox.ciphertext)
        combined.append(sealedBox.tag)
        return combined
    }

    /// Decrypts `data` produced by `encrypt(data:passphrase:)`.
    public static func decrypt(data: Data, passphrase: String) throws -> Data {
        // Minimum: 12 (nonce) + 0 (ciphertext) + 16 (tag) = 28 bytes
        guard data.count >= 28 else {
            throw SharingError.encryptionFailed("Ciphertext is too short to be valid.")
        }

        let key = try deriveKey(from: passphrase)

        let nonceData   = data.prefix(12)
        let tagData     = data.suffix(16)
        let cipherData  = data.dropFirst(12).dropLast(16)

        do {
            let nonce = try AES.GCM.Nonce(data: nonceData)
            let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: cipherData, tag: tagData)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw SharingError.encryptionFailed(error.localizedDescription)
        }
    }

    // MARK: - Private Key Derivation

    private static func deriveKey(from passphrase: String) throws -> SymmetricKey {
        guard let passphraseData = passphrase.data(using: .utf8) else {
            throw SharingError.encryptionFailed("Passphrase contains non-UTF-8 characters.")
        }

        // Use HKDF with SHA-256 to derive a 256-bit key.
        let inputKey = SymmetricKey(data: passphraseData)
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKey,
            salt: saltData,
            info: infoData,
            outputByteCount: 32
        )
    }
}
