import Foundation
import CoreGraphics

public struct OCRBoundingBox: Sendable {
    public let text: String
    public let bounds: CGRect

    public init(text: String, bounds: CGRect) {
        self.text = text
        self.bounds = bounds
    }
}

public struct OCRResult: Sendable {
    public let text: String
    public let confidence: Double
    public let language: String?
    public let boundingBoxes: [OCRBoundingBox]

    public init(
        text: String,
        confidence: Double,
        language: String? = nil,
        boundingBoxes: [OCRBoundingBox] = []
    ) {
        self.text = text
        self.confidence = confidence
        self.language = language
        self.boundingBoxes = boundingBoxes
    }
}
