import Foundation
import Vision
import OSLog

private let logger = Logger(subsystem: "com.snapforge", category: "OCRIndexer")

// MARK: - OCRIndexer

actor OCRIndexer {

    // MARK: State

    var isPaused: Bool = false

    private let maxConcurrentTasks = 2
    private var activeTasks: Int = 0

    // MARK: Public Interface

    /// Processes a captured image and returns the extracted OCR text.
    func processCapture(_ result: CaptureResult) async throws -> String {
        while activeTasks >= maxConcurrentTasks {
            try await Task.sleep(for: .milliseconds(200))
        }

        guard !isPaused else {
            logger.info("OCRIndexer: paused — skipping OCR for \(result.id)")
            return ""
        }

        activeTasks += 1
        defer { activeTasks -= 1 }

        let text = try await runOCR(filePath: result.filePath)
        logger.info("OCRIndexer: extracted \(text.count) characters for capture \(result.id)")
        return text
    }

    /// Re-indexes all provided records, throttled to maxConcurrentTasks.
    func reindexAll(records: [any Sendable]) async throws {
        // Records are expected to be CaptureResult or similar types with filePath.
        // We accept [any Sendable] per the protocol specification; cast internally.
        guard let captureRecords = records as? [CaptureResult] else {
            logger.warning("OCRIndexer: reindexAll received unsupported record types")
            return
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            var queued = 0
            for record in captureRecords {
                if queued >= maxConcurrentTasks {
                    try await group.next()
                    queued -= 1
                }
                group.addTask {
                    _ = try await self.processCapture(record)
                }
                queued += 1
            }
            try await group.waitForAll()
        }
    }

    // MARK: Private OCR

    private func runOCR(filePath: String) async throws -> String {
        let fileURL = URL(fileURLWithPath: filePath)

        guard let cgImageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(cgImageSource, 0, nil) else {
            throw CaptureError.screenCaptureKitFailure("OCR: failed to load image at \(filePath)")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
