import Foundation
import CoreGraphics

// MARK: - CaptureType

public enum CaptureType: String, Sendable, Codable, CaseIterable {
    case screenshot
    case scrolling
    case video
    case gif
    case ocr
    case pin
}

// MARK: - CaptureState

public enum CaptureState: Sendable {
    case idle
    case selecting(CaptureType)
    case capturing
    case processing
    case completed(CaptureResult)
    case error(CaptureError)
}

// MARK: - CaptureError

public enum CaptureError: Error, LocalizedError, Sendable {
    case permissionDenied
    case regionInvalid
    case alreadyInProgress
    case screenCaptureKitFailure(String)
    case diskSpaceInsufficient

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen recording permission was denied. Grant access in System Settings > Privacy & Security > Screen Recording."
        case .regionInvalid:
            return "The specified capture region is invalid or empty."
        case .alreadyInProgress:
            return "A capture is already in progress."
        case .screenCaptureKitFailure(let message):
            return "ScreenCaptureKit error: \(message)"
        case .diskSpaceInsufficient:
            return "Insufficient disk space to save the capture."
        }
    }
}

// MARK: - CaptureResult

public struct CaptureResult: Sendable {
    public let id: UUID
    public let captureType: CaptureType
    public let filePath: String
    public let thumbnailPath: String?
    public let timestamp: Date
    public let sourceAppBundleID: String?
    public let sourceAppName: String?
    public let windowTitle: String?
    public let dimensions: CGSize
    public let fileSize: Int64

    public init(
        id: UUID = UUID(),
        captureType: CaptureType,
        filePath: String,
        thumbnailPath: String? = nil,
        timestamp: Date = Date(),
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil,
        windowTitle: String? = nil,
        dimensions: CGSize,
        fileSize: Int64
    ) {
        self.id = id
        self.captureType = captureType
        self.filePath = filePath
        self.thumbnailPath = thumbnailPath
        self.timestamp = timestamp
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.windowTitle = windowTitle
        self.dimensions = dimensions
        self.fileSize = fileSize
    }
}

// MARK: - RecordingCodec

public enum RecordingCodec: String, Sendable, Codable {
    case h264
    case h265
    case prores
    case gif
}

// MARK: - RecordingConfig

public struct RecordingConfig: Sendable {
    public let fps: Int
    public let codec: RecordingCodec
    public let bitrate: Int
    public let resolutionScale: Double
    public let autoAdjustQuality: Bool
    public let maxDuration: TimeInterval?

    public init(
        fps: Int = 30,
        codec: RecordingCodec = .h265,
        bitrate: Int = 8_000_000,
        resolutionScale: Double = 1.0,
        autoAdjustQuality: Bool = true,
        maxDuration: TimeInterval? = nil
    ) {
        self.fps = fps
        self.codec = codec
        self.bitrate = bitrate
        self.resolutionScale = resolutionScale
        self.autoAdjustQuality = autoAdjustQuality
        self.maxDuration = maxDuration
    }
}

// MARK: - RecordingMetrics

public struct RecordingMetrics: Sendable {
    public let cpuUsage: Double
    public let gpuUsage: Double
    public let currentFPS: Double
    public let duration: TimeInterval
    public let frameCount: Int
    public let fileSize: Int64

    public init(
        cpuUsage: Double,
        gpuUsage: Double,
        currentFPS: Double,
        duration: TimeInterval,
        frameCount: Int,
        fileSize: Int64
    ) {
        self.cpuUsage = cpuUsage
        self.gpuUsage = gpuUsage
        self.currentFPS = currentFPS
        self.duration = duration
        self.frameCount = frameCount
        self.fileSize = fileSize
    }
}

// MARK: - TrimRange

public struct TrimRange: Sendable {
    public let startSeconds: Double
    public let endSeconds: Double?

    public init(startSeconds: Double, endSeconds: Double? = nil) {
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
    }
}
