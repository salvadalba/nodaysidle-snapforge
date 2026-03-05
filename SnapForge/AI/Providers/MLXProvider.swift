import Foundation
import CoreGraphics

// MARK: - MLXProvider

actor MLXProvider: @preconcurrency InferenceProvider {

    // MARK: - Properties

    nonisolated let providerType: ProviderType = .mlx

    private let modelsDirectory: URL

    // MARK: - Init

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(filePath: NSHomeDirectory())

        self.modelsDirectory = appSupport
            .appending(path: "SnapForge/Models/mlx", directoryHint: .isDirectory)
    }

    // MARK: - InferenceProvider

    var status: ProviderStatus {
        get async {
            #if arch(arm64)
            let hasModels = (try? FileManager.default.contentsOfDirectory(
                at: modelsDirectory,
                includingPropertiesForKeys: nil
            ).isEmpty == false) ?? false

            return hasModels ? .ready : .unavailable(reason: "No MLX models found at \(modelsDirectory.path)")
            #else
            return .unavailable(reason: "MLX requires Apple Silicon (arm64)")
            #endif
        }
    }

    func generate(prompt: String, context: InferenceContext) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                #if arch(arm64)
                do {
                    try self.assertModelAvailable()
                    // MLX inference would be wired here via Swift bindings.
                    // Stub: emit a placeholder token stream.
                    let tokens = ["[MLX", " model", " response", " placeholder]"]
                    for token in tokens {
                        try await Task.sleep(for: .milliseconds(40))
                        continuation.yield(token)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
                #else
                continuation.finish(
                    throwing: AIError.providerUnavailable(.mlx)
                )
                #endif
            }
        }
    }

    func detectRegions(in image: CGImage) async throws -> [DetectedRegion] {
        #if arch(arm64)
        try assertModelAvailable()
        // MLX-based detection stub — wire to actual model when bundled.
        return []
        #else
        throw AIError.providerUnavailable(.mlx)
        #endif
    }

    func performOCR(on image: CGImage) async throws -> OCRResult {
        #if arch(arm64)
        try assertModelAvailable()
        // MLX-based OCR stub — wire to actual model when bundled.
        return OCRResult(text: "", confidence: 0, language: nil, boundingBoxes: [])
        #else
        throw AIError.providerUnavailable(.mlx)
        #endif
    }

    nonisolated func estimateTokenCount(_ text: String) -> Int {
        max(1, text.count / 4)
    }

    // MARK: - Private

    private func assertModelAvailable() throws {
        let exists = (try? FileManager.default.contentsOfDirectory(
            at: modelsDirectory,
            includingPropertiesForKeys: nil
        ).isEmpty == false) ?? false

        guard exists else {
            throw AIError.modelNotLoaded
        }
    }
}
