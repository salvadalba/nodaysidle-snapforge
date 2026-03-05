import Foundation
import CoreGraphics

// MARK: - CaptureServiceProtocol

public protocol CaptureServiceProtocol: Sendable {
    /// Captures a screenshot of the full screen or a specific region.
    func captureScreenshot(region: CGRect?) async throws -> CaptureResult

    /// Captures a scrolling region that extends beyond the visible viewport.
    func captureScrolling(region: CGRect) async throws -> CaptureResult

    /// Captures a region and runs OCR on it, returning a result with extracted text.
    func captureOCRRegion(region: CGRect?) async throws -> CaptureResult

    /// Starts a screen recording with the specified configuration.
    func startRecording(config: RecordingConfig) async throws

    /// Stops an active recording and returns the saved result.
    func stopRecording() async throws -> CaptureResult

    /// Pins a captured region as a floating overlay window.
    func pinCapture(region: CGRect) async throws

    /// Reset state machine to idle so subsequent captures can proceed.
    func resetToIdle() async

    /// The current capture state.
    var captureState: CaptureState { get }

    /// An async stream that emits state transitions as they occur.
    var stateStream: AsyncStream<CaptureState> { get }
}
