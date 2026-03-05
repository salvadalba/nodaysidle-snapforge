import SwiftUI

// MARK: - AnnotationSuggestionPanel

/// Panel that presents AI-generated annotation suggestions for a captured image.
/// The user can accept all suggestions at once or accept/reject each individually.
struct AnnotationSuggestionPanel: View {

    // MARK: - Input

    let suggestions: [AnnotationSuggestion]
    var onAccept: (([AnnotationSuggestion]) -> Void)?
    var onDismiss: (() -> Void)?

    // MARK: - State

    @State private var pendingSuggestions: [AnnotationSuggestion] = []

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            suggestionList
            Divider()
            footer
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            pendingSuggestions = suggestions
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Annotation Suggestions")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(.primary)
                Text("\(pendingSuggestions.count) suggestion\(pendingSuggestions.count == 1 ? "" : "s") remaining")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.warmGray)
            }
            Spacer()
            Button(action: { onDismiss?() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(DesignSystem.Colors.warmGray)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
        }
        .padding(DesignSystem.Spacing.md)
    }

    // MARK: - Suggestion List

    private var suggestionList: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.sm) {
                if pendingSuggestions.isEmpty {
                    Text("All suggestions handled.")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.warmGray)
                        .padding(.vertical, DesignSystem.Spacing.lg)
                } else {
                    ForEach(pendingSuggestions, id: \.label) { suggestion in
                        suggestionRow(for: suggestion)
                    }
                }
            }
            .padding(DesignSystem.Spacing.md)
        }
        .frame(maxHeight: 320)
    }

    private func suggestionRow(for suggestion: AnnotationSuggestion) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Colour swatch
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: hexValue(from: suggestion.color)))
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text(suggestion.label)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(.primary)
                    Text(suggestion.type)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.warmGray)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.warmGray.opacity(0.15))
                        )
                }
                Text("\(Int(suggestion.confidence * 100))% confidence")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.warmGray)
            }

            Spacer()

            // Accept
            Button("Accept") {
                accept(suggestion)
            }
            .font(DesignSystem.Typography.callout)
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(DesignSystem.Colors.forgeOrange)
            )

            // Reject
            Button("Reject") {
                reject(suggestion)
            }
            .font(DesignSystem.Typography.callout)
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(DesignSystem.Colors.systemBlack)
            )
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.06))
        )
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Reject All") {
                pendingSuggestions.removeAll()
                onDismiss?()
            }
            .font(DesignSystem.Typography.body)
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(DesignSystem.Colors.systemBlack)
            )

            Spacer()

            Button("Accept All") {
                let all = pendingSuggestions
                pendingSuggestions.removeAll()
                onAccept?(all)
            }
            .font(DesignSystem.Typography.body)
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(DesignSystem.Colors.forgeOrange)
            )
            .disabled(pendingSuggestions.isEmpty)
        }
        .padding(DesignSystem.Spacing.md)
    }

    // MARK: - Actions

    private func accept(_ suggestion: AnnotationSuggestion) {
        pendingSuggestions.removeAll { $0.label == suggestion.label }
        onAccept?([suggestion])
    }

    private func reject(_ suggestion: AnnotationSuggestion) {
        pendingSuggestions.removeAll { $0.label == suggestion.label }
    }

    // MARK: - Helpers

    /// Parses a CSS-style hex string ("#RRGGBB" or "RRGGBB") into a UInt.
    private func hexValue(from string: String) -> UInt {
        let cleaned = string.trimmingCharacters(in: .init(charactersIn: "#"))
        return UInt(cleaned, radix: 16) ?? 0xE8620A
    }
}

// MARK: - Preview

#Preview {
    let suggestions: [AnnotationSuggestion] = [
        AnnotationSuggestion(type: "arrow", region: CGRect(x: 0.1, y: 0.1, width: 0.3, height: 0.1), label: "Sign In Button", color: "#E8620A", confidence: 0.92),
        AnnotationSuggestion(type: "highlight", region: CGRect(x: 0.4, y: 0.3, width: 0.5, height: 0.05), label: "Error Message", color: "#FF3B30", confidence: 0.85),
        AnnotationSuggestion(type: "rectangle", region: CGRect(x: 0.1, y: 0.5, width: 0.8, height: 0.2), label: "Content Area", color: "#FF9F0A", confidence: 0.78)
    ]

    AnnotationSuggestionPanel(
        suggestions: suggestions,
        onAccept: { accepted in print("Accepted: \(accepted.map(\.label))") },
        onDismiss: {}
    )
    .frame(width: 480)
    .padding()
}
