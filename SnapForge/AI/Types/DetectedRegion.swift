import Foundation
import CoreGraphics

public struct DetectedRegion: Sendable {
    public let label: String
    public let bounds: CGRect
    public let confidence: Double
    public let elementType: String

    public init(
        label: String,
        bounds: CGRect,
        confidence: Double,
        elementType: String
    ) {
        self.label = label
        self.bounds = bounds
        self.confidence = confidence
        self.elementType = elementType
    }
}
