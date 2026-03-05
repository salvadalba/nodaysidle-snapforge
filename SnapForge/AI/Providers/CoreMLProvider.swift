import Foundation
import CoreGraphics
import Vision
import CoreML

// MARK: - CoreMLProvider

actor CoreMLProvider: @preconcurrency InferenceProvider {

    // MARK: - Properties

    nonisolated let providerType: ProviderType = .coreml

    /// Compute units selected at init based on hardware.
    private let computeUnits: MLComputeUnits

    // MARK: - Init

    init() {
        // Prefer Neural Engine on Apple Silicon; fall back to CPU+GPU on Intel
        #if arch(arm64)
        self.computeUnits = .cpuAndNeuralEngine
        #else
        self.computeUnits = .cpuAndGPU
        #endif
    }

    // MARK: - InferenceProvider

    var status: ProviderStatus {
        get async { .ready }
    }

    func generate(prompt: String, context: InferenceContext) -> AsyncThrowingStream<String, Error> {
        // Simulated streaming response — replace with bundled CoreML LLM when available.
        let words = simulatedResponse(for: prompt).components(separatedBy: " ")
        return AsyncThrowingStream { continuation in
            Task {
                for word in words {
                    try await Task.sleep(for: .milliseconds(30))
                    continuation.yield(word + " ")
                }
                continuation.finish()
            }
        }
    }

    func detectRegions(in image: CGImage) async throws -> [DetectedRegion] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNGenerateAttentionBasedSaliencyImageRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let results = request.results as? [VNSaliencyImageObservation],
                      let observation = results.first else {
                    continuation.resume(returning: [])
                    return
                }

                let salientObjects = observation.salientObjects ?? []
                let regions = salientObjects.enumerated().map { index, obj in
                    DetectedRegion(
                        label: "Region \(index + 1)",
                        bounds: obj.boundingBox,
                        confidence: Double(obj.confidence),
                        elementType: "salient"
                    )
                }
                continuation.resume(returning: regions)
            }

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    func performOCR(on image: CGImage) async throws -> OCRResult {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: OCRResult(text: "", confidence: 0))
                    return
                }

                var fullText: [String] = []
                var totalConfidence: Double = 0
                var boxes: [OCRBoundingBox] = []

                for observation in observations {
                    guard let candidate = observation.topCandidates(1).first else { continue }
                    fullText.append(candidate.string)
                    totalConfidence += Double(candidate.confidence)
                    boxes.append(OCRBoundingBox(
                        text: candidate.string,
                        bounds: observation.boundingBox
                    ))
                }

                let averageConfidence = observations.isEmpty
                    ? 0
                    : totalConfidence / Double(observations.count)

                let result = OCRResult(
                    text: fullText.joined(separator: "\n"),
                    confidence: averageConfidence,
                    language: nil,
                    boundingBoxes: boxes
                )
                continuation.resume(returning: result)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    nonisolated func estimateTokenCount(_ text: String) -> Int {
        // Rough approximation: ~4 characters per token
        max(1, text.count / 4)
    }

    // MARK: - Private

    private func simulatedResponse(for prompt: String) -> String {
        "SnapForge CoreML provider received your prompt. A real model response would appear here once a CoreML LLM is bundled with the application. Your prompt contained approximately \(estimateTokenCount(prompt)) tokens."
    }
}
