import SwiftUI

// MARK: - RegionDetectionOverlay

/// A ZStack overlay that renders detected UI regions as interactive
/// semi-transparent bounding boxes over a capture image.
///
/// `imageSize` must be the rendered size of the image view so that
/// `DetectedRegion.bounds` (normalised 0–1 CGRect) maps correctly.
struct RegionDetectionOverlay: View {

    // MARK: - Input

    let regions: [DetectedRegion]
    /// The pixel size of the rendered image below this overlay.
    let imageSize: CGSize
    /// Called when the user taps/clicks a region.
    var onRegionSelected: ((DetectedRegion) -> Void)?

    // MARK: - State

    @State private var selectedRegion: DetectedRegion?
    @State private var hoveredID: String?
    @State private var appeared: Bool = false

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(regions, id: \.label) { region in
                regionView(for: region)
            }
        }
        .frame(width: imageSize.width, height: imageSize.height)
        .onKeyPress(.escape) {
            selectedRegion = nil
            return .handled
        }
        .onAppear { appeared = true }
    }

    // MARK: - Region View

    @ViewBuilder
    private func regionView(for region: DetectedRegion) -> some View {
        let rect = denormalize(region.bounds)
        let isHovered = hoveredID == region.label
        let isSelected = selectedRegion?.label == region.label

        ZStack(alignment: .topLeading) {
            // Fill
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    isSelected
                        ? DesignSystem.Colors.forgeOrange.opacity(0.25)
                        : DesignSystem.Colors.forgeOrange.opacity(0.10)
                )

            // Border
            RoundedRectangle(cornerRadius: 4)
                .stroke(
                    isHovered
                        ? DesignSystem.Colors.sparkGold
                        : DesignSystem.Colors.forgeOrange,
                    lineWidth: isSelected ? 2.0 : 1.5
                )

            // Label badge
            regionLabel(for: region)
                .offset(x: 4, y: -18)
        }
        .frame(width: rect.width, height: rect.height)
        .offset(x: rect.minX, y: rect.minY)
        .onHover { inside in
            hoveredID = inside ? region.label : nil
        }
        .onTapGesture {
            selectedRegion = region
            onRegionSelected?(region)
        }
        .phaseAnimator(appeared ? [0.0, 1.0] : [0.0]) { view, opacity in
            view.opacity(opacity)
        } animation: { _ in
            .easeOut(duration: 0.3)
        }
    }

    private func regionLabel(for region: DetectedRegion) -> some View {
        HStack(spacing: 4) {
            Text(region.label)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(.white)
                .lineLimit(1)

            Text("\(Int(region.confidence * 100))%")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(DesignSystem.Colors.forgeOrange)
        )
    }

    // MARK: - Coordinate Mapping

    /// Converts a normalised [0, 1] CGRect to a CGRect in the image's pixel space.
    private func denormalize(_ normalized: CGRect) -> CGRect {
        CGRect(
            x: normalized.minX * imageSize.width,
            y: normalized.minY * imageSize.height,
            width: normalized.width * imageSize.width,
            height: normalized.height * imageSize.height
        )
    }
}

// MARK: - Preview

#Preview {
    let regions: [DetectedRegion] = [
        DetectedRegion(label: "Button", bounds: CGRect(x: 0.1, y: 0.2, width: 0.2, height: 0.08), confidence: 0.94, elementType: "button"),
        DetectedRegion(label: "Text Field", bounds: CGRect(x: 0.1, y: 0.4, width: 0.5, height: 0.06), confidence: 0.88, elementType: "textField"),
        DetectedRegion(label: "Image", bounds: CGRect(x: 0.6, y: 0.1, width: 0.35, height: 0.5), confidence: 0.76, elementType: "image")
    ]

    ZStack {
        Color(hex: 0xF5F5F7)
        RegionDetectionOverlay(
            regions: regions,
            imageSize: CGSize(width: 600, height: 400)
        ) { region in
            print("Selected: \(region.label)")
        }
    }
    .frame(width: 600, height: 400)
}
