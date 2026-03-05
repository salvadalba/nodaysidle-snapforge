import SwiftUI

// MARK: - CaptureTypeItem

private struct CaptureTypeItem: Identifiable {
    let id: CaptureType
    let symbol: String
    let label: String
    let shortcutHint: String
}

private let captureTypeItems: [CaptureTypeItem] = [
    CaptureTypeItem(id: .screenshot, symbol: "camera",                       label: "Screenshot",  shortcutHint: "1"),
    CaptureTypeItem(id: .scrolling,  symbol: "arrow.up.and.down.text.horizontal", label: "Scrolling",   shortcutHint: "2"),
    CaptureTypeItem(id: .video,      symbol: "record.circle",                label: "Video",       shortcutHint: "3"),
    CaptureTypeItem(id: .gif,        symbol: "photo.on.rectangle",           label: "GIF",         shortcutHint: "4"),
    CaptureTypeItem(id: .ocr,        symbol: "doc.text.viewfinder",          label: "OCR",         shortcutHint: "5"),
    CaptureTypeItem(id: .pin,        symbol: "pin",                          label: "Pin",         shortcutHint: "6"),
]

// MARK: - CommandPaletteView

struct CommandPaletteView: View {

    // MARK: Properties

    @State private var selectedIndex: Int = 0
    let onSelect: (CaptureType) -> Void
    let onDismiss: () -> Void

    // MARK: Body

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 8)

            VStack(spacing: DesignSystem.Spacing.md) {
                // Title
                Text("Capture")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(.primary)
                    .padding(.top, DesignSystem.Spacing.md)

                // Radial/grid layout of 6 capture type buttons
                LazyVGrid(
                    columns: [
                        GridItem(.fixed(100), spacing: DesignSystem.Spacing.md),
                        GridItem(.fixed(100), spacing: DesignSystem.Spacing.md),
                        GridItem(.fixed(100), spacing: DesignSystem.Spacing.md)
                    ],
                    spacing: DesignSystem.Spacing.md
                ) {
                    ForEach(Array(captureTypeItems.enumerated()), id: \.element.id) { index, item in
                        CaptureTypeButton(
                            item: item,
                            isSelected: selectedIndex == index
                        ) {
                            selectedIndex = index
                            onSelect(item.id)
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.md)

                // Keyboard hint
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "arrow.left.arrow.right")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 11))
                    Text("Arrow keys to navigate · Return to select · Esc to dismiss")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, DesignSystem.Spacing.sm)
            }
        }
        .frame(width: 380, height: 280)
        .onKeyPress(.escape)       { onDismiss(); return .handled }
        .onKeyPress(.return)       { commitSelection(); return .handled }
        .onKeyPress(.leftArrow)    { navigateLeft(); return .handled }
        .onKeyPress(.rightArrow)   { navigateRight(); return .handled }
        .onKeyPress(.upArrow)      { navigateUp(); return .handled }
        .onKeyPress(.downArrow)    { navigateDown(); return .handled }
        .onKeyPress(characters: CharacterSet(charactersIn: "123456"), phases: .down) { keyPress in
            handleNumberKey(keyPress.characters)
            return .handled
        }
    }

    // MARK: - Navigation

    private func navigateLeft() {
        selectedIndex = max(0, selectedIndex - 1)
    }

    private func navigateRight() {
        selectedIndex = min(captureTypeItems.count - 1, selectedIndex + 1)
    }

    private func navigateUp() {
        let newIndex = selectedIndex - 3
        if newIndex >= 0 { selectedIndex = newIndex }
    }

    private func navigateDown() {
        let newIndex = selectedIndex + 3
        if newIndex < captureTypeItems.count { selectedIndex = newIndex }
    }

    private func commitSelection() {
        let item = captureTypeItems[selectedIndex]
        onSelect(item.id)
    }

    private func handleNumberKey(_ characters: String) {
        guard let first = characters.first,
              let digit = Int(String(first)),
              (1...6).contains(digit) else { return }
        selectedIndex = digit - 1
        commitSelection()
    }
}

// MARK: - CaptureTypeButton

private struct CaptureTypeButton: View {

    let item: CaptureTypeItem
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isHovered: Bool = false
    @State private var isAppeared: Bool = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                ZStack {
                    // Selection ring
                    Circle()
                        .strokeBorder(
                            isSelected ? DesignSystem.Colors.forgeOrange : Color.clear,
                            lineWidth: 2.5
                        )
                        .frame(width: 64, height: 64)

                    // Hover fill
                    Circle()
                        .fill(isHovered ? DesignSystem.Colors.sparkGold.opacity(0.15) : Color.clear)
                        .frame(width: 58, height: 58)

                    // Icon
                    Image(systemName: item.symbol)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(isSelected ? DesignSystem.Colors.forgeOrange : .primary)
                        .frame(width: 58, height: 58)
                }

                // Label
                Text(item.label)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(isSelected ? DesignSystem.Colors.forgeOrange : .primary)
                    .lineLimit(1)

                // Shortcut hint
                Text(item.shortcutHint)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .scaleEffect(isAppeared ? 1.0 : 0.7)
        .opacity(isAppeared ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.65).delay(Double(captureTypeItems.firstIndex(where: { $0.id == item.id }) ?? 0) * 0.045)) {
                isAppeared = true
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    CommandPaletteView(
        onSelect: { type in print("Selected: \(type)") },
        onDismiss: { print("Dismissed") }
    )
    .padding(40)
    .background(Color.gray.opacity(0.3))
}
#endif
