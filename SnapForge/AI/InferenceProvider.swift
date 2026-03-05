import Foundation
import CoreGraphics

// MARK: - ProviderType

public enum ProviderType: String, Sendable, Codable, CaseIterable {
    case coreml
    case mlx
    case ollama
    case openai
    case anthropic
}

// MARK: - ProviderStatus

public enum ProviderStatus: Sendable {
    case available
    case unavailable(reason: String)
    case loading
    case ready
}

// MARK: - InferenceProvider

public protocol InferenceProvider: Sendable {
    var providerType: ProviderType { get }
    var status: ProviderStatus { get async }

    func generate(prompt: String, context: InferenceContext) -> AsyncThrowingStream<String, Error>
    func detectRegions(in image: CGImage) async throws -> [DetectedRegion]
    func performOCR(on image: CGImage) async throws -> OCRResult
    func estimateTokenCount(_ text: String) -> Int
}
