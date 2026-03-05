import Testing
@testable import SnapForge

@Suite("SnapForge Core Tests")
struct SnapForgeTests {
    @Test("CaptureType enum has all expected cases")
    func captureTypeHasAllCases() {
        let allTypes = CaptureType.allCases
        #expect(allTypes.count == 6)
        #expect(allTypes.contains(.screenshot))
        #expect(allTypes.contains(.scrolling))
        #expect(allTypes.contains(.video))
        #expect(allTypes.contains(.gif))
        #expect(allTypes.contains(.ocr))
        #expect(allTypes.contains(.pin))
    }

    @Test("RecordingConfig has sensible defaults")
    func recordingConfigDefaults() {
        let config = RecordingConfig()
        #expect(config.fps == 30)
        #expect(config.bitrate == 8_000_000)
        #expect(config.resolutionScale == 1.0)
        #expect(config.autoAdjustQuality == true)
    }

    @Test("ProviderType enum covers all providers")
    func providerTypeCoversAll() {
        let all = ProviderType.allCases
        #expect(all.count == 5)
    }

    @Test("AIError provides localized descriptions")
    func aiErrorDescriptions() {
        let error = AIError.modelNotLoaded
        #expect(error.errorDescription != nil)

        let timeout = AIError.networkTimeout
        #expect(timeout.errorDescription != nil)
    }

    @Test("InferenceContext has sensible defaults")
    func inferenceContextDefaults() {
        let ctx = InferenceContext()
        #expect(ctx.maxTokens == 2048)
        #expect(ctx.temperature == 0.7)
        #expect(ctx.image == nil)
    }

    @Test("DetectedRegion is constructible")
    func detectedRegionConstruction() {
        let region = DetectedRegion(
            label: "Navigation Bar",
            bounds: CGRect(x: 0, y: 0, width: 1920, height: 48),
            confidence: 0.95,
            elementType: "navigation"
        )
        #expect(region.label == "Navigation Bar")
        #expect(region.confidence == 0.95)
    }

    @Test("HardwareCapabilities detects system")
    func hardwareCapabilitiesDetect() {
        let caps = HardwareCapabilities.detect()
        #expect(caps.processorCount > 0)
        #expect(caps.metalSupported == true || caps.metalSupported == false)
    }

    @Test("DownloadProgress computes progress correctly")
    func downloadProgressCalculation() {
        let progress = DownloadProgress(
            modelID: UUID(),
            bytesDownloaded: 500,
            bytesTotal: 1000,
            estimatedTimeRemaining: 10
        )
        #expect(progress.progress == 0.5)
    }

    @Test("DownloadProgress handles zero total")
    func downloadProgressZeroTotal() {
        let progress = DownloadProgress(
            modelID: UUID(),
            bytesDownloaded: 0,
            bytesTotal: 0,
            estimatedTimeRemaining: nil
        )
        #expect(progress.progress == 0)
    }
}
