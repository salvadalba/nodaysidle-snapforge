import Foundation
import CoreGraphics

public struct InferenceContext: Sendable {
    public let image: CGImage?
    public let ocrText: String?
    public let captureID: UUID?
    public let maxTokens: Int
    public let temperature: Double

    public init(
        image: CGImage? = nil,
        ocrText: String? = nil,
        captureID: UUID? = nil,
        maxTokens: Int = 2048,
        temperature: Double = 0.7
    ) {
        self.image = image
        self.ocrText = ocrText
        self.captureID = captureID
        self.maxTokens = maxTokens
        self.temperature = temperature
    }
}
