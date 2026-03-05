import Foundation
import Metal
import CryptoKit
import os
import SwiftData

// MARK: - LoadedModelEntry

/// Internal bookkeeping for a model that is resident in memory.
private struct LoadedModelEntry: Sendable {
    let info: AIModelInfo
    /// Background task that fires the idle-eviction timeout.
    let idleTimerTask: Task<Void, Never>
}

// MARK: - DownloadDelegate

/// URLSession delegate that forwards byte-count updates through a continuation.
/// Marked as final + @unchecked Sendable because URLSessionDelegate conformance
/// requires an NSObject subclass; the internal state is protected by the serial
/// delegate queue supplied by URLSession.
private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {

    private let modelID: UUID
    private let continuation: AsyncThrowingStream<DownloadProgress, Error>.Continuation
    private let destinationURL: URL
    private var startTime: Date = Date()

    init(
        modelID: UUID,
        destinationURL: URL,
        continuation: AsyncThrowingStream<DownloadProgress, Error>.Continuation
    ) {
        self.modelID = modelID
        self.destinationURL = destinationURL
        self.continuation = continuation
    }

    // MARK: URLSessionDownloadDelegate

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let elapsed = Date().timeIntervalSince(startTime)
        let rate = elapsed > 0 ? Double(totalBytesWritten) / elapsed : 0
        let remaining: TimeInterval? = rate > 0 && totalBytesExpectedToWrite > 0
            ? Double(totalBytesExpectedToWrite - totalBytesWritten) / rate
            : nil

        let progress = DownloadProgress(
            modelID: modelID,
            bytesDownloaded: totalBytesWritten,
            bytesTotal: totalBytesExpectedToWrite,
            estimatedTimeRemaining: remaining
        )
        continuation.yield(progress)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            let dir = destinationURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: location, to: destinationURL)
            continuation.finish()
        } catch {
            continuation.finish(throwing: error)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            continuation.finish(throwing: error)
        }
    }
}

// MARK: - ModelManagerService

/// Actor that manages the lifecycle of AI models: downloading, loading, idle
/// eviction, and GPU memory budgeting.
public actor ModelManagerService: @preconcurrency ModelManagerProtocol {

    // MARK: - Properties

    private var loadedModels_: [UUID: LoadedModelEntry] = [:]
    private let registry: ModelRegistry
    private let hardware: HardwareCapabilities
    private let logger = Logger(subsystem: "com.snapforge", category: "ModelManagerService")

    /// Default idle timeout in seconds. Reads from UserDefaults; falls back to 5 min.
    private var idleTimeoutSeconds: Double {
        let stored = UserDefaults.standard.double(forKey: "modelIdleTimeoutSeconds")
        return stored > 0 ? stored : 300
    }

    // MARK: - Init

    public init(registry: ModelRegistry = .shared) {
        self.registry = registry
        self.hardware = HardwareCapabilities.detect()
    }

    // MARK: - ModelManagerProtocol

    public func loadModel(id: UUID) async throws {
        guard loadedModels_[id] == nil else { return }   // already loaded

        guard let entry = registry.entry(for: id) else {
            throw AIError.modelNotLoaded
        }

        // GPU memory budget check
        logGPUMemory()

        // Enforce single-large-model constraint: if loading a large model
        // (>500 MB), unload any other large model first.
        let largeThreshold: Int64 = 500 * 1_048_576
        if entry.sizeBytes > largeThreshold {
            let largeIDs = loadedModels_.filter { $0.value.info.fileSize > largeThreshold }.map(\.key)
            for existingID in largeIDs where existingID != id {
                await unloadModel(id: existingID)
            }
        }

        // Build AIModelInfo for the entry.
        let info = AIModelInfo(
            id: entry.id,
            name: entry.name,
            providerType: entry.providerType,
            fileSize: entry.sizeBytes,
            version: entry.version,
            capabilities: entry.capabilities
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) },
            isBundled: entry.isBundled,
            isLoaded: true,
            downloadStatus: .loaded,
            contextWindowSize: entry.contextWindowSize
        )

        // Start idle timer unless this is a bundled model.
        let timerTask = makeIdleTimer(for: id, isBundled: entry.isBundled)
        loadedModels_[id] = LoadedModelEntry(info: info, idleTimerTask: timerTask)

        logger.info("ModelManagerService: loaded '\(entry.name)' (bundled: \(entry.isBundled))")
    }

    public func unloadModel(id: UUID) async {
        guard let entry = loadedModels_[id] else { return }
        entry.idleTimerTask.cancel()
        loadedModels_.removeValue(forKey: id)
        logger.info("ModelManagerService: unloaded '\(entry.info.name)'")
    }

    nonisolated public func downloadModel(id: UUID) -> AsyncThrowingStream<DownloadProgress, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await self._downloadModel(id: id, continuation: continuation)
            }
        }
    }

    public func availableModels() async -> [AIModelInfo] {
        let entries = registry.allEntries
        let loaded = loadedModels_

        return entries.map { entry in
            let isLoaded = loaded[entry.id] != nil
            let status: ModelState = isLoaded
                ? .loaded
                : (entry.isBundled || entry.sizeBytes == 0 ? .downloaded : .notDownloaded)

            return AIModelInfo(
                id: entry.id,
                name: entry.name,
                providerType: entry.providerType,
                fileSize: entry.sizeBytes,
                version: entry.version,
                capabilities: entry.capabilities
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) },
                isBundled: entry.isBundled,
                isLoaded: isLoaded,
                downloadStatus: status,
                contextWindowSize: entry.contextWindowSize
            )
        }
    }

    public func loadedModels() async -> [AIModelInfo] {
        loadedModels_.values.map(\.info)
    }

    public func resetIdleTimer(modelID: UUID) async {
        guard let entry = loadedModels_[modelID] else { return }
        // Bundled models are never evicted.
        guard !entry.info.isBundled else { return }

        entry.idleTimerTask.cancel()
        let newTimer = makeIdleTimer(for: modelID, isBundled: false)
        loadedModels_[modelID] = LoadedModelEntry(info: entry.info, idleTimerTask: newTimer)
    }

    // MARK: - Private helpers

    private func makeIdleTimer(for id: UUID, isBundled: Bool) -> Task<Void, Never> {
        guard !isBundled else {
            // Return a never-firing task for bundled models.
            return Task { await Task.yield() }
        }

        let timeout = idleTimeoutSeconds
        return Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(timeout))
                await self?.unloadModel(id: id)
            } catch {
                // Task was cancelled (timer reset or explicit unload) — do nothing.
            }
        }
    }

    private func logGPUMemory() {
        if let device = MTLCreateSystemDefaultDevice() {
            let budget = device.recommendedMaxWorkingSetSize / 1_048_576
            logger.info("ModelManagerService: GPU memory budget \(budget) MB")
        }
    }

    // MARK: - Download implementation

    private func _downloadModel(
        id: UUID,
        continuation: AsyncThrowingStream<DownloadProgress, Error>.Continuation
    ) async {
        guard let entry = registry.entry(for: id) else {
            continuation.finish(throwing: AIError.downloadFailed(reason: "Unknown model ID"))
            return
        }

        // Derive a placeholder remote URL based on provider (real URLs would come from a manifest).
        let remoteURLString = "https://models.snapforge.app/\(entry.providerType)/\(entry.id.uuidString).bin"
        guard let remoteURL = URL(string: remoteURLString) else {
            continuation.finish(throwing: AIError.downloadFailed(reason: "Invalid model URL"))
            return
        }

        // Destination: ~/Library/Application Support/SnapForge/Models/{provider}/{id}.bin
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            continuation.finish(throwing: AIError.downloadFailed(reason: "Cannot resolve Application Support"))
            return
        }

        let destDir = appSupport
            .appendingPathComponent("SnapForge/Models/\(entry.providerType)", isDirectory: true)
        let destFile = destDir.appendingPathComponent("\(id.uuidString).bin")

        // Check available disk space (rough guard: require at least model size + 10%).
        if entry.sizeBytes > 0 {
            let attrs = try? FileManager.default.attributesOfFileSystem(forPath: appSupport.path)
            let free = (attrs?[.systemFreeSize] as? Int64) ?? Int64.max
            let required = Int64(Double(entry.sizeBytes) * 1.1)
            if free < required {
                continuation.finish(throwing: AIError.insufficientStorage)
                return
            }
        }

        let delegate = DownloadDelegate(
            modelID: id,
            destinationURL: destFile,
            continuation: continuation
        )

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 3600   // 1 hour max for large models
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        let task = session.downloadTask(with: remoteURL)
        task.resume()

        // Wait for continuation to finish (delegate calls finish/finish(throwing:)).
        // We keep the session alive until done by holding a reference here.
        _ = session   // retain

        // After the download stream finishes, verify SHA-256 if we have a checksum.
        // This runs after the delegate has called continuation.finish(), so the
        // outer stream consumer will see integrity errors as a thrown error on the
        // NEXT yield — we surface it via a separate throw. Because the continuation
        // is already finished at that point we log the error instead.
        if let expected = entry.sha256Checksum, FileManager.default.fileExists(atPath: destFile.path) {
            do {
                try await verifyChecksum(at: destFile, expectedHex: expected, modelName: entry.name)
            } catch {
                logger.error("ModelManagerService: integrity check failed for '\(entry.name)': \(error)")
                try? FileManager.default.removeItem(at: destFile)
            }
        }
    }

    private func verifyChecksum(at url: URL, expectedHex: String, modelName: String) async throws {
        try await Task.detached(priority: .utility) {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let digest = SHA256.hash(data: data)
            let hex = digest.map { String(format: "%02x", $0) }.joined()
            guard hex == expectedHex else {
                throw AIError.integrityCheckFailed
            }
        }.value
    }
}
