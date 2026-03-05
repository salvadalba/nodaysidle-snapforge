import Foundation
import SwiftData

// MARK: - AIModel

@Model
public final class AIModel {

    // MARK: - Stored Properties

    public var id: UUID
    public var name: String

    /// One of: coreml / mlx / ollama / openai / anthropic
    public var providerType: String

    /// Absolute path to the model artefact on disk, nil for cloud API models.
    public var modelPath: String?

    public var sizeBytes: Int64

    public var version: String

    /// Comma-separated capability tags, e.g. "ocr,region_detection,captioning"
    public var capabilities: String

    /// True when the model ships inside the app bundle.
    public var isBundled: Bool

    /// Whether the model is currently resident in memory.
    public var isLoaded: Bool

    /// One of: mlmodelc / gguf / mlx_safetensors / cloud_api
    public var format: String

    /// Optional quantisation label, e.g. "q4_0", "int8".
    public var quantization: String?

    /// Maximum context length in tokens.
    public var contextWindowSize: Int

    /// One of: notDownloaded / downloading / downloaded / failed
    public var downloadStatus: String

    /// Hex-encoded SHA-256 checksum of the model artefact; nil for cloud models.
    public var sha256Checksum: String?

    public var lastUsed: Date?

    // MARK: - Init

    public init(
        id: UUID = UUID(),
        name: String,
        providerType: String,
        modelPath: String? = nil,
        sizeBytes: Int64 = 0,
        version: String = "1.0",
        capabilities: String = "",
        isBundled: Bool = false,
        isLoaded: Bool = false,
        format: String,
        quantization: String? = nil,
        contextWindowSize: Int = 4096,
        downloadStatus: String = "notDownloaded",
        sha256Checksum: String? = nil,
        lastUsed: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.providerType = providerType
        self.modelPath = modelPath
        self.sizeBytes = sizeBytes
        self.version = version
        self.capabilities = capabilities
        self.isBundled = isBundled
        self.isLoaded = isLoaded
        self.format = format
        self.quantization = quantization
        self.contextWindowSize = contextWindowSize
        self.downloadStatus = downloadStatus
        self.sha256Checksum = sha256Checksum
        self.lastUsed = lastUsed
    }

    // MARK: - Derived helpers

    /// Parsed capability list.
    public var capabilityList: [String] {
        capabilities.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// Convenience for checking whether the model is a large model (>500 MB).
    public var isLargeModel: Bool {
        sizeBytes > 500 * 1_048_576
    }
}
