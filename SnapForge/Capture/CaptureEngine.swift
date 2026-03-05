import Foundation
import CoreGraphics
import ScreenCaptureKit
import ImageIO
import UniformTypeIdentifiers
import OSLog

private let logger = Logger(subsystem: "com.snapforge", category: "CaptureEngine")

private struct UncheckedSendableBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}

// MARK: - CaptureEngine

actor CaptureEngine: @preconcurrency CaptureServiceProtocol {

    // MARK: State

    private(set) var captureState: CaptureState = .idle

    private var stateContinuation: AsyncStream<CaptureState>.Continuation?

    nonisolated let stateStream: AsyncStream<CaptureState>

    // MARK: Init

    init() {
        var continuation: AsyncStream<CaptureState>.Continuation?
        let stream = AsyncStream<CaptureState> { cont in
            continuation = cont
        }
        self.stateStream = stream
        self.stateContinuation = continuation
    }

    // MARK: Permission

    private func ensurePermission() async throws {
        guard CGPreflightScreenCaptureAccess() else {
            let granted = CGRequestScreenCaptureAccess()
            if !granted {
                throw CaptureError.permissionDenied
            }
            return
        }
    }

    // MARK: State Machine

    private func transition(to state: CaptureState) {
        captureState = state
        stateContinuation?.yield(state)
        logger.info("CaptureEngine state → \(String(describing: state))")
    }

    // MARK: Directory

    private func capturesDirectory() throws -> URL {
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
        return dir
    }

    // MARK: Source App Detection

    private func detectSourceApp() -> (bundleID: String?, name: String?, windowTitle: String?) {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[CFString: Any]] else {
            return (nil, nil, nil)
        }

        // Find the frontmost app window (layer 0, non-background)
        let frontmost = windowList.first { info in
            let layer = info[kCGWindowLayer] as? Int ?? Int.max
            let ownerName = info[kCGWindowOwnerName] as? String ?? ""
            return layer == 0 && ownerName != "SnapForge" && ownerName != "Window Server"
        }

        let bundleID = frontmost?[kCGWindowOwnerPID]
            .flatMap { pid -> String? in
                guard let pidNumber = pid as? Int32 else { return nil }
                return NSRunningApplication(processIdentifier: pid_t(pidNumber))?.bundleIdentifier
            }

        let name = frontmost?[kCGWindowOwnerName] as? String
        let title = frontmost?[kCGWindowName] as? String

        return (bundleID, name, title)
    }

    // MARK: Thumbnail Generation

    private func generateThumbnail(from imageURL: URL) throws -> URL {
        guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw CaptureError.screenCaptureKitFailure("Failed to read image for thumbnail")
        }

        let maxDim: CGFloat = 256
        let scale = min(maxDim / CGFloat(image.width), maxDim / CGFloat(image.height))
        let thumbWidth = Int(CGFloat(image.width) * scale)
        let thumbHeight = Int(CGFloat(image.height) * scale)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: thumbWidth,
            height: thumbHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw CaptureError.screenCaptureKitFailure("Failed to create thumbnail context")
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: thumbWidth, height: thumbHeight))

        guard let thumbImage = context.makeImage() else {
            throw CaptureError.screenCaptureKitFailure("Failed to render thumbnail")
        }

        let thumbURL = imageURL.deletingLastPathComponent()
            .appendingPathComponent(imageURL.deletingPathExtension().lastPathComponent + "_thumb.jpg")

        guard let dest = CGImageDestinationCreateWithURL(thumbURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw CaptureError.screenCaptureKitFailure("Failed to create thumbnail destination")
        }
        CGImageDestinationAddImage(dest, thumbImage, [kCGImageDestinationLossyCompressionQuality: 0.75] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            throw CaptureError.screenCaptureKitFailure("Failed to write thumbnail")
        }

        return thumbURL
    }

    // MARK: Screenshot via SCStream

    private func performScreenshotCapture(region: CGRect?) async throws -> URL {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let display = content.displays.first else {
            throw CaptureError.screenCaptureKitFailure("No display available")
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(display.frame.width)
        config.height = Int(display.frame.height)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false

        if let region {
            config.sourceRect = region
            config.width = Int(region.width)
            config.height = Int(region.height)
        }

        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        let captureOutput = SnapForgeSCStreamOutput()
        try stream.addStreamOutput(captureOutput, type: .screen, sampleHandlerQueue: .global(qos: .userInitiated))

        try await stream.startCapture()
        let sampleBuffer = try await captureOutput.awaitFirstSample()
        try await stream.stopCapture()

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            throw CaptureError.screenCaptureKitFailure("Failed to extract image buffer")
        }

        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ), let cgImage = context.makeImage() else {
            throw CaptureError.screenCaptureKitFailure("Failed to create CGImage from pixel buffer")
        }

        let destDir = try capturesDirectory()
        let fileURL = destDir.appendingPathComponent("\(UUID().uuidString).png")

        guard let dest = CGImageDestinationCreateWithURL(fileURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw CaptureError.screenCaptureKitFailure("Failed to create PNG destination")
        }
        CGImageDestinationAddImage(dest, cgImage, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw CaptureError.screenCaptureKitFailure("Failed to write PNG file")
        }

        return fileURL
    }

    // MARK: CaptureServiceProtocol

    func captureScreenshot(region: CGRect?) async throws -> CaptureResult {
        guard case .idle = captureState else { throw CaptureError.alreadyInProgress }

        try await ensurePermission()
        transition(to: .selecting(.screenshot))
        transition(to: .capturing)

        do {
            let fileURL = try await performScreenshotCapture(region: region)
            transition(to: .processing)

            let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = attrs[.size] as? Int64 ?? 0

            let cgSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil)
            let props = cgSource.flatMap { CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any] }
            let width = props?[kCGImagePropertyPixelWidth] as? Int ?? 0
            let height = props?[kCGImagePropertyPixelHeight] as? Int ?? 0

            let thumbURL = try? generateThumbnail(from: fileURL)
            let sourceInfo = detectSourceApp()

            let result = CaptureResult(
                id: UUID(),
                captureType: .screenshot,
                filePath: fileURL.path,
                thumbnailPath: thumbURL?.path,
                timestamp: Date(),
                sourceAppBundleID: sourceInfo.bundleID,
                sourceAppName: sourceInfo.name,
                windowTitle: sourceInfo.windowTitle,
                dimensions: CGSize(width: width, height: height),
                fileSize: fileSize
            )

            transition(to: .completed(result))
            return result
        } catch let error as CaptureError {
            transition(to: .error(error))
            throw error
        } catch {
            let wrapped = CaptureError.screenCaptureKitFailure(error.localizedDescription)
            transition(to: .error(wrapped))
            throw wrapped
        }
    }

    func captureScrolling(region: CGRect) async throws -> CaptureResult {
        guard region.width > 0, region.height > 0 else { throw CaptureError.regionInvalid }
        guard case .idle = captureState else { throw CaptureError.alreadyInProgress }

        try await ensurePermission()
        transition(to: .selecting(.scrolling))
        transition(to: .capturing)

        do {
            // Scrolling capture: take initial region screenshot as starting point.
            // Full scrolling stitching requires user interaction; this captures the visible region.
            let fileURL = try await performScreenshotCapture(region: region)
            transition(to: .processing)

            let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = attrs[.size] as? Int64 ?? 0
            let thumbURL = try? generateThumbnail(from: fileURL)
            let sourceInfo = detectSourceApp()

            let result = CaptureResult(
                id: UUID(),
                captureType: .scrolling,
                filePath: fileURL.path,
                thumbnailPath: thumbURL?.path,
                timestamp: Date(),
                sourceAppBundleID: sourceInfo.bundleID,
                sourceAppName: sourceInfo.name,
                windowTitle: sourceInfo.windowTitle,
                dimensions: region.size,
                fileSize: fileSize
            )

            transition(to: .completed(result))
            return result
        } catch let error as CaptureError {
            transition(to: .error(error))
            throw error
        } catch {
            let wrapped = CaptureError.screenCaptureKitFailure(error.localizedDescription)
            transition(to: .error(wrapped))
            throw wrapped
        }
    }

    func captureOCRRegion(region: CGRect?) async throws -> CaptureResult {
        guard case .idle = captureState else { throw CaptureError.alreadyInProgress }

        try await ensurePermission()
        transition(to: .selecting(.ocr))
        transition(to: .capturing)

        do {
            let fileURL = try await performScreenshotCapture(region: region)
            transition(to: .processing)

            let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = attrs[.size] as? Int64 ?? 0

            let cgSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil)
            let props = cgSource.flatMap { CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any] }
            let width = props?[kCGImagePropertyPixelWidth] as? Int ?? 0
            let height = props?[kCGImagePropertyPixelHeight] as? Int ?? 0

            let thumbURL = try? generateThumbnail(from: fileURL)
            let sourceInfo = detectSourceApp()

            let result = CaptureResult(
                id: UUID(),
                captureType: .ocr,
                filePath: fileURL.path,
                thumbnailPath: thumbURL?.path,
                timestamp: Date(),
                sourceAppBundleID: sourceInfo.bundleID,
                sourceAppName: sourceInfo.name,
                windowTitle: sourceInfo.windowTitle,
                dimensions: CGSize(width: width, height: height),
                fileSize: fileSize
            )

            transition(to: .completed(result))
            return result
        } catch let error as CaptureError {
            transition(to: .error(error))
            throw error
        } catch {
            let wrapped = CaptureError.screenCaptureKitFailure(error.localizedDescription)
            transition(to: .error(wrapped))
            throw wrapped
        }
    }

    func startRecording(config: RecordingConfig) async throws {
        guard case .idle = captureState else { throw CaptureError.alreadyInProgress }
        try await ensurePermission()
        transition(to: .capturing)
        // Recording is delegated to RecordingPipeline. CaptureEngine marks state only.
        logger.info("Recording started with codec: \(config.codec.rawValue), fps: \(config.fps)")
    }

    func stopRecording() async throws -> CaptureResult {
        guard case .capturing = captureState else {
            throw CaptureError.screenCaptureKitFailure("No active recording")
        }

        transition(to: .processing)

        // Placeholder result — RecordingPipeline owns actual file production.
        let result = CaptureResult(
            id: UUID(),
            captureType: .video,
            filePath: "",
            thumbnailPath: nil,
            timestamp: Date(),
            sourceAppBundleID: nil,
            sourceAppName: nil,
            windowTitle: nil,
            dimensions: .zero,
            fileSize: 0
        )

        transition(to: .completed(result))
        return result
    }

    func pinCapture(region: CGRect) async throws {
        guard region.width > 0, region.height > 0 else { throw CaptureError.regionInvalid }
        try await ensurePermission()
        // Pin display logic is handled by the UI layer (NSPanel overlay).
        // CaptureEngine captures the region content to provide as the pin source.
        transition(to: .selecting(.pin))
        _ = try await performScreenshotCapture(region: region)
        transition(to: .idle)
    }
}

// MARK: - SCStreamOutput

/// Minimal SCStreamOutput implementation that delivers the first captured sample.
private final class SnapForgeSCStreamOutput: NSObject, SCStreamOutput, @unchecked Sendable {
    private var continuation: CheckedContinuation<CMSampleBuffer, Error>?
    private let lock = NSLock()

    func awaitFirstSample() async throws -> CMSampleBuffer {
        try await withCheckedThrowingContinuation { [weak self] cont in
            self?.lock.lock()
            self?.continuation = cont
            self?.lock.unlock()
        }
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .screen else { return }
        lock.lock()
        let cont = continuation
        continuation = nil
        lock.unlock()
        let wrapper = UncheckedSendableBox(sampleBuffer)
        cont?.resume(returning: wrapper.value)
    }

    func stream(_ stream: SCStream, didStopWithError error: any Error) {
        lock.lock()
        let cont = continuation
        continuation = nil
        lock.unlock()
        cont?.resume(throwing: error)
    }
}
