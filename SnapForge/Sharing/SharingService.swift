import Foundation
import Security
import OSLog

private let logger = Logger(subsystem: "com.snapforge", category: "SharingService")

// MARK: - PrivacyMode

public enum PrivacyMode: String, Sendable, Codable, CaseIterable {
    case localOnly
    case upload
    case askEveryTime
}

// MARK: - ShareResult

public struct ShareResult: Sendable {
    public let shareURL: URL
    public let expiry: Date
    public let encrypted: Bool

    public init(shareURL: URL, expiry: Date, encrypted: Bool) {
        self.shareURL = shareURL
        self.expiry = expiry
        self.encrypted = encrypted
    }
}

// MARK: - KeychainCredentials (interface definition)

/// Interface for S3-compatible credential storage in Keychain.
/// Concrete storage uses Security framework; placeholder returns nil until configured.
private enum KeychainCredentials {

    private static let service = "com.snapforge.sharing"

    static func store(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecValueData:   data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      key,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else { return nil }
        return value
    }
}

// MARK: - SharingService

actor SharingService {

    // MARK: Properties

    private let defaults: UserDefaults
    private let urlSession: URLSession

    var privacyMode: PrivacyMode {
        get {
            let raw = defaults.string(forKey: "com.snapforge.sharing.privacyMode") ?? PrivacyMode.askEveryTime.rawValue
            return PrivacyMode(rawValue: raw) ?? .askEveryTime
        }
        set {
            defaults.set(newValue.rawValue, forKey: "com.snapforge.sharing.privacyMode")
        }
    }

    // MARK: Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        self.urlSession = URLSession(configuration: config)
    }

    // MARK: Upload

    /// Encrypts the file at `captureID`'s path and uploads it to the configured S3 bucket.
    /// - Parameters:
    ///   - captureID: UUID of the capture (used to locate the file and name the S3 object).
    ///   - expiry: When the share link should expire.
    ///   - password: Optional passphrase; if nil, a random 16-byte hex key is generated.
    /// - Returns: `ShareResult` containing the public download URL and encryption status.
    func upload(captureID: UUID, expiry: Date, password: String?) async throws -> ShareResult {
        guard privacyMode != .localOnly else {
            throw SharingError.privacyModeBlocked
        }

        let resolvedPassword = password ?? generateEphemeralKey()

        // Locate the file — real implementation would query LibraryService.
        // Using a mock path here since SharingService does not hold a reference to LibraryService.
        let filePath = captureFilePath(for: captureID)
        let plainData = try Data(contentsOf: URL(fileURLWithPath: filePath))

        let encryptedData = try EncryptionService.encrypt(data: plainData, passphrase: resolvedPassword)

        let uploadURL = try buildUploadURL(captureID: captureID)
        try await putWithRetry(data: encryptedData, to: uploadURL, maxRetries: 3)

        let shareURL = buildShareURL(captureID: captureID)
        logger.info("SharingService: uploaded \(captureID) (\(encryptedData.count) bytes encrypted)")
        return ShareResult(shareURL: shareURL, expiry: expiry, encrypted: true)
    }

    // MARK: - Private Helpers

    private func putWithRetry(data: Data, to url: URL, maxRetries: Int) async throws {
        var lastError: Error = SharingError.storageBucketUnreachable
        let delays: [UInt64] = [1_000_000_000, 2_000_000_000, 4_000_000_000]  // 1s, 2s, 4s

        for attempt in 0..<maxRetries {
            do {
                try await performPUT(data: data, to: url)
                return
            } catch {
                lastError = error
                logger.warning("SharingService: upload attempt \(attempt + 1) failed: \(error.localizedDescription)")
                if attempt < maxRetries - 1 {
                    try await Task.sleep(nanoseconds: delays[min(attempt, delays.count - 1)])
                }
            }
        }
        throw SharingError.uploadFailed(retryCount: maxRetries)
    }

    private func performPUT(data: Data, to url: URL) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        if let accessKey = KeychainCredentials.load(key: "s3AccessKey"),
           let secretKey = KeychainCredentials.load(key: "s3SecretKey") {
            // In production, compute AWS SigV4 or pre-signed URL here.
            // For now, attach basic credentials to the request header.
            let credentials = "\(accessKey):\(secretKey)"
            if let credData = credentials.data(using: .utf8) {
                request.setValue("Basic \(credData.base64EncodedString())", forHTTPHeaderField: "Authorization")
            }
        }

        let (_, response) = try await urlSession.upload(for: request, from: data)

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw SharingError.storageBucketUnreachable
        }
    }

    private func buildUploadURL(captureID: UUID) throws -> URL {
        let endpoint = KeychainCredentials.load(key: "s3Endpoint") ?? "https://s3.example.com"
        let bucket   = KeychainCredentials.load(key: "s3Bucket")   ?? "snapforge-uploads"
        let key      = "\(captureID.uuidString).enc"
        guard let url = URL(string: "\(endpoint)/\(bucket)/\(key)") else {
            throw SharingError.storageBucketUnreachable
        }
        return url
    }

    private func buildShareURL(captureID: UUID) -> URL {
        let base = KeychainCredentials.load(key: "s3PublicBase") ?? "https://cdn.snapforge.app"
        return URL(string: "\(base)/\(captureID.uuidString)")!
    }

    private func captureFilePath(for captureID: UUID) -> String {
        // Placeholder — production code queries LibraryService for the actual path.
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("SnapForge/captures/\(captureID.uuidString)").path
    }

    private func generateEphemeralKey() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Credential Management (public interface)

    func storeS3Credentials(endpoint: String, bucket: String, accessKey: String, secretKey: String, publicBase: String) {
        KeychainCredentials.store(key: "s3Endpoint",   value: endpoint)
        KeychainCredentials.store(key: "s3Bucket",     value: bucket)
        KeychainCredentials.store(key: "s3AccessKey",  value: accessKey)
        KeychainCredentials.store(key: "s3SecretKey",  value: secretKey)
        KeychainCredentials.store(key: "s3PublicBase", value: publicBase)
    }
}
