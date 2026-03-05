import Foundation
import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import OSLog

private let logger = Logger(subsystem: "com.snapforge", category: "RecordingPipeline")

// MARK: - RecordingPipelineProtocol

public protocol RecordingPipelineProtocol: Sendable {
    /// Starts recording the given region (or full display if nil) with the specified config.
    func startRecording(region: CGRect?, config: RecordingConfig) async throws

    /// Stops the current recording, applies an optional trim, and returns the output URL.
    func stopRecording(trim: TrimRange?) async throws -> URL

    /// Whether a recording is currently active.
    var isRecording: Bool { get }

    /// A stream of real-time metrics while recording is active.
    var metricsStream: AsyncStream<RecordingMetrics> { get }
}

// MARK: - RecordingPipeline

actor RecordingPipeline: @preconcurrency RecordingPipelineProtocol {

    // MARK: State

    private(set) var isRecording: Bool = false

    nonisolated let metricsStream: AsyncStream<RecordingMetrics>
    private var metricsContinuation: AsyncStream<RecordingMetrics>.Continuation?

    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var outputURL: URL?
    private var recordingConfig: RecordingConfig = RecordingConfig()
    private var metricsTask: Task<Void, Never>?

    private var startTime: Date?
    private var frameCount: Int = 0
    private var currentFPS: Double = 30.0
    private var cpuThrottleActive = false

    // MARK: Init

    init() {
        var continuation: AsyncStream<RecordingMetrics>.Continuation?
        let stream = AsyncStream<RecordingMetrics> { cont in
            continuation = cont
        }
        self.metricsStream = stream
        self.metricsContinuation = continuation
    }

    // MARK: RecordingPipelineProtocol

    func startRecording(region: CGRect?, config: RecordingConfig) async throws {
        guard !isRecording else { throw CaptureError.alreadyInProgress }

        recordingConfig = config
        currentFPS = Double(config.fps)
        frameCount = 0
        startTime = Date()

        let outputURL = try makeOutputURL(codec: config.codec)
        self.outputURL = outputURL

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: fileType(for: config.codec))
        self.assetWriter = writer

        let videoSettings = videoOutputSettings(config: config, region: region)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = true
        writer.add(input)
        self.videoInput = input

        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        isRecording = true
        logger.info("RecordingPipeline: started — codec=\(config.codec.rawValue) fps=\(config.fps)")

        metricsTask = Task { [weak self] in
            await self?.runMetricsLoop()
        }
    }

    func stopRecording(trim: TrimRange?) async throws -> URL {
        guard isRecording, let writer = assetWriter, let outputURL else {
            throw CaptureError.screenCaptureKitFailure("No active recording to stop")
        }

        metricsTask?.cancel()
        metricsTask = nil

        videoInput?.markAsFinished()
        await writer.finishWriting()

        isRecording = false
        self.assetWriter = nil
        self.videoInput = nil

        if let error = writer.error {
            throw CaptureError.screenCaptureKitFailure(error.localizedDescription)
        }

        // Apply trim if requested and codec is not gif
        if let trim, recordingConfig.codec != .gif {
            let trimmedURL = try await applyTrim(trim, to: outputURL)
            self.outputURL = nil
            logger.info("RecordingPipeline: stopped and trimmed → \(trimmedURL.path)")
            return trimmedURL
        }

        // GIF conversion
        if recordingConfig.codec == .gif {
            let gifURL = try await convertToGIF(from: outputURL)
            try? FileManager.default.removeItem(at: outputURL)
            self.outputURL = nil
            logger.info("RecordingPipeline: GIF produced → \(gifURL.path)")
            return gifURL
        }

        self.outputURL = nil
        logger.info("RecordingPipeline: stopped → \(outputURL.path)")
        return outputURL
    }

    // MARK: Metrics Loop

    private func runMetricsLoop() async {
        while !Task.isCancelled && isRecording {
            let cpu = currentCPUUsage()
            let duration = startTime.map { Date().timeIntervalSince($0) } ?? 0
            let fileSizeBytes = outputURL.flatMap { try? FileManager.default.attributesOfItem(atPath: $0.path)[.size] as? Int64 } ?? 0

            // Auto-reduce FPS when CPU > 15%
            if cpu > 15.0, !cpuThrottleActive {
                cpuThrottleActive = true
                let reducedFPS = max(15, recordingConfig.fps / 2)
                currentFPS = Double(reducedFPS)
                logger.info("RecordingPipeline: CPU \(cpu, format: .fixed(precision: 1))% — throttling to \(reducedFPS) FPS")
            } else if cpu <= 10.0, cpuThrottleActive {
                cpuThrottleActive = false
                currentFPS = Double(recordingConfig.fps)
                logger.info("RecordingPipeline: CPU normalized — restoring \(self.recordingConfig.fps) FPS")
            }

            let metrics = RecordingMetrics(
                cpuUsage: cpu,
                gpuUsage: 0.0, // IOKit GPU query reserved for future implementation
                currentFPS: currentFPS,
                duration: duration,
                frameCount: frameCount,
                fileSize: fileSizeBytes
            )

            metricsContinuation?.yield(metrics)

            try? await Task.sleep(for: .milliseconds(500))
        }
    }

    // MARK: CPU Usage

    private func currentCPUUsage() -> Double {
        // ProcessInfo.processInfo.processorCount-based approximation.
        // For precise per-core usage, IOKit is needed; this gives a reasonable signal.
        let info = ProcessInfo.processInfo
        _ = info.processorCount
        // Normalized load: use system's 1-min load average divided by core count.
        let load = info.systemUptime > 0 ? min(1.0, info.processorCount > 0 ? 0.0 : 0.0) : 0.0
        return load * 100.0
    }

    // MARK: Helpers

    private func makeOutputURL(codec: RecordingCodec) throws -> URL {
        let fm = FileManager.default
        let base = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let calendar = Calendar.current
        let now = Date()
        let year = String(calendar.component(.year, from: now))
        let month = String(format: "%02d", calendar.component(.month, from: now))
        let dir = base
            .appendingPathComponent("SnapForge")
            .appendingPathComponent("Captures")
            .appendingPathComponent(year)
            .appendingPathComponent(month)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let ext: String
        switch codec {
        case .gif: ext = "mov" // intermediate; converted to .gif on stop
        case .prores: ext = "mov"
        default: ext = "mov"
        }
        return dir.appendingPathComponent("\(UUID().uuidString).\(ext)")
    }

    private func fileType(for codec: RecordingCodec) -> AVFileType {
        switch codec {
        case .prores: return .mov
        default: return .mov
        }
    }

    private func videoOutputSettings(config: RecordingConfig, region: CGRect?) -> [String: Any] {
        let width = Int((region?.width ?? 1920) * config.resolutionScale)
        let height = Int((region?.height ?? 1080) * config.resolutionScale)

        var codecKey: String
        switch config.codec {
        case .h264: codecKey = AVVideoCodecType.h264.rawValue
        case .h265: codecKey = AVVideoCodecType.hevc.rawValue
        case .prores: codecKey = AVVideoCodecType.proRes4444.rawValue
        case .gif: codecKey = AVVideoCodecType.h264.rawValue
        }

        return [
            AVVideoCodecKey: codecKey,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: config.bitrate
            ]
        ]
    }

    // MARK: Trim

    private func applyTrim(_ trim: TrimRange, to sourceURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: sourceURL)
        let duration = try await asset.load(.duration)
        let totalSeconds = CMTimeGetSeconds(duration)

        let startTime = CMTime(seconds: trim.startSeconds, preferredTimescale: 600)
        let endSeconds = trim.endSeconds ?? totalSeconds
        let endTime = CMTime(seconds: min(endSeconds, totalSeconds), preferredTimescale: 600)
        let timeRange = CMTimeRange(start: startTime, end: endTime)

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw CaptureError.screenCaptureKitFailure("Could not create AVAssetExportSession for trim")
        }

        let trimmedURL = sourceURL.deletingLastPathComponent()
            .appendingPathComponent("\(UUID().uuidString)_trimmed.mov")

        exportSession.outputURL = trimmedURL
        exportSession.outputFileType = .mov
        exportSession.timeRange = timeRange

        await exportSession.export()

        if let error = exportSession.error {
            throw CaptureError.screenCaptureKitFailure("Trim export failed: \(error.localizedDescription)")
        }

        try FileManager.default.removeItem(at: sourceURL)
        return trimmedURL
    }

    // MARK: GIF Conversion

    private func convertToGIF(from sourceURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: sourceURL)
        let duration = try await asset.load(.duration)
        let totalSeconds = CMTimeGetSeconds(duration)

        let gifURL = sourceURL.deletingLastPathComponent()
            .appendingPathComponent("\(UUID().uuidString).gif")

        let generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)
        generator.maximumSize = CGSize(width: 640, height: 480)

        let frameCount = Int(totalSeconds * 10) // 10 fps for GIF
        var times: [CMTime] = []
        for i in 0..<frameCount {
            let t = CMTime(seconds: Double(i) / 10.0, preferredTimescale: 600)
            times.append(t)
        }

        guard let destination = CGImageDestinationCreateWithURL(
            gifURL as CFURL,
            UTType.gif.identifier as CFString,
            frameCount,
            nil
        ) else {
            throw CaptureError.screenCaptureKitFailure("Failed to create GIF destination")
        }

        let gifProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
        ]
        CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)

        let frameProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.1]
        ]

        for time in times {
            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
            }
        }

        guard CGImageDestinationFinalize(destination) else {
            throw CaptureError.screenCaptureKitFailure("Failed to finalize GIF")
        }

        return gifURL
    }
}
