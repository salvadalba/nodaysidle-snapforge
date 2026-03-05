import Foundation
import CoreGraphics

public struct AnnotationSuggestion: Sendable {
    public let type: String
    public let region: CGRect
    public let label: String
    public let color: String
    public let confidence: Double

    public init(
        type: String,
        region: CGRect,
        label: String,
        color: String,
        confidence: Double
    ) {
        self.type = type
        self.region = region
        self.label = label
        self.color = color
        self.confidence = confidence
    }
}
