import Foundation

// MARK: - ModelState

public enum ModelState: Sendable, Codable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case loading
    case loaded
    case unloading
    case error(String)
}

// MARK: - DownloadProgress

public struct DownloadProgress: Sendable {
    public let modelID: UUID
    public let bytesDownloaded: Int64
    public let bytesTotal: Int64
    public let estimatedTimeRemaining: TimeInterval?

    public var progress: Double {
        guard bytesTotal > 0 else { return 0 }
        return Double(bytesDownloaded) / Double(bytesTotal)
    }

    public init(
        modelID: UUID,
        bytesDownloaded: Int64,
        bytesTotal: Int64,
        estimatedTimeRemaining: TimeInterval? = nil
    ) {
        self.modelID = modelID
        self.bytesDownloaded = bytesDownloaded
        self.bytesTotal = bytesTotal
        self.estimatedTimeRemaining = estimatedTimeRemaining
    }
}

// MARK: - AIModelInfo

public struct AIModelInfo: Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let providerType: String
    public let fileSize: Int64
    public let version: String
    public let capabilities: [String]
    public let isBundled: Bool
    public let isLoaded: Bool
    public let downloadStatus: ModelState
    public let contextWindowSize: Int

    public init(
        id: UUID,
        name: String,
        providerType: String,
        fileSize: Int64,
        version: String,
        capabilities: [String],
        isBundled: Bool,
        isLoaded: Bool,
        downloadStatus: ModelState,
        contextWindowSize: Int
    ) {
        self.id = id
        self.name = name
        self.providerType = providerType
        self.fileSize = fileSize
        self.version = version
        self.capabilities = capabilities
        self.isBundled = isBundled
        self.isLoaded = isLoaded
        self.downloadStatus = downloadStatus
        self.contextWindowSize = contextWindowSize
    }
}

// MARK: - ModelManagerProtocol

public protocol ModelManagerProtocol: Sendable {
    func loadModel(id: UUID) async throws
    func unloadModel(id: UUID) async
    func downloadModel(id: UUID) -> AsyncThrowingStream<DownloadProgress, Error>
    func availableModels() async -> [AIModelInfo]
    func loadedModels() async -> [AIModelInfo]
    func resetIdleTimer(modelID: UUID) async
}
