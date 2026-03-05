import SwiftUI

// MARK: - ActionType

public enum ActionType: String, Sendable, CaseIterable, Identifiable {
    case annotate
    case copy
    case save
    case cloud
    case background
    case pin
    case delete

    public var id: String { rawValue }

    var symbol: String {
        switch self {
        case .annotate:    return "pencil.tip"
        case .copy:        return "doc.on.doc"
        case .save:        return "square.and.arrow.down"
        case .cloud:       return "icloud.and.arrow.up"
        case .background:  return "photo.on.rectangle.angled"
        case .pin:         return "pin"
        case .delete:      return "trash"
        }
    }

    var label: String {
        switch self {
        case .annotate:    return "Annotate"
        case .copy:        return "Copy"
        case .save:        return "Save"
        case .cloud:       return "Share"
        case .background:  return "Wallpaper"
        case .pin:         return "Pin"
        case .delete:      return "Delete"
        }
    }

    var isDestructive: Bool { self == .delete }
}

// MARK: - ActionMemory

struct ActionMemory: Codable {
    var lastActionByType: [String: String]

    init() { lastActionByType = [:] }

    func lastAction(for captureType: CaptureType) -> ActionType? {
        guard let raw = lastActionByType[captureType.rawValue] else { return nil }
        return ActionType(rawValue: raw)
    }

    mutating func record(action: ActionType, for captureType: CaptureType) {
        lastActionByType[captureType.rawValue] = action.rawValue
    }
}

// MARK: - ActionBarView

struct ActionBarView: View {

    // MARK: Properties

    let captureType: CaptureType
    let onAction: (ActionType) -> Void

    @State private var selectedIndex: Int = 0
    @State private var memory: ActionMemory = Self.loadMemory()

    private static let memoryKey = "com.snapforge.actionMemory"

    // MARK: Body

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(Array(ActionType.allCases.enumerated()), id: \.element.id) { index, action in
                ActionButton(
                    action: action,
                    isSelected: selectedIndex == index,
                    isLastUsed: memory.lastAction(for: captureType) == action
                ) {
                    selectedIndex = index
                    performAction(action)
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onKeyPress(.return) {
            let action = ActionType.allCases[selectedIndex]
            performAction(action)
            return .handled
        }
        .onKeyPress(.leftArrow) {
            selectedIndex = max(0, selectedIndex - 1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            selectedIndex = min(ActionType.allCases.count - 1, selectedIndex + 1)
            return .handled
        }
    }

    // MARK: - Action Dispatch

    private func performAction(_ action: ActionType) {
        var updated = memory
        updated.record(action: action, for: captureType)
        memory = updated
        Self.saveMemory(updated)
        onAction(action)
    }

    // MARK: - Persistence

    private static func loadMemory() -> ActionMemory {
        guard let data = UserDefaults.standard.data(forKey: memoryKey),
              let decoded = try? JSONDecoder().decode(ActionMemory.self, from: data) else {
            return ActionMemory()
        }
        return decoded
    }

    private static func saveMemory(_ memory: ActionMemory) {
        guard let data = try? JSONEncoder().encode(memory) else { return }
        UserDefaults.standard.set(data, forKey: memoryKey)
    }
}

// MARK: - ActionButton

private struct ActionButton: View {

    let action: ActionType
    let isSelected: Bool
    let isLastUsed: Bool
    let onTap: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                ZStack {
                    // Last-used highlight ring
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            isLastUsed ? DesignSystem.Colors.sparkGold : Color.clear,
                            lineWidth: 1.5
                        )
                        .frame(width: 44, height: 44)

                    // Selected state fill
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected
                              ? DesignSystem.Colors.forgeOrange.opacity(0.15)
                              : (isHovered ? Color.primary.opacity(0.08) : Color.clear))
                        .frame(width: 44, height: 44)

                    // Icon — 2px stroke rendering
                    Image(systemName: action.symbol)
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(iconColor)
                        .frame(width: 44, height: 44)
                }

                Text(action.label)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(action.isDestructive ? .red : .primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var iconColor: Color {
        if action.isDestructive { return .red }
        if isSelected { return DesignSystem.Colors.forgeOrange }
        if isLastUsed { return DesignSystem.Colors.sparkGold }
        return .primary
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ActionBarView(captureType: .screenshot) { action in
        print("Action: \(action)")
    }
    .padding(40)
    .background(Color(hex: 0x1C1C1E))
}
#endif
