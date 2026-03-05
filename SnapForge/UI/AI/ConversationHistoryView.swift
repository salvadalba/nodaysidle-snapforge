import SwiftUI

// MARK: - ConversationHistoryView

/// Scrollable list of past prompt/response exchanges for a capture record,
/// with a new-prompt text field at the bottom.
struct ConversationHistoryView: View {

    // MARK: - Input

    let entries: [ConversationEntry]
    /// Called when the user submits a new prompt.
    var onSubmitPrompt: ((String) -> Void)?
    /// Called when the user taps "Re-run" on an existing entry.
    var onRerunEntry: ((ConversationEntry) -> Void)?

    // MARK: - State

    @State private var newPromptText: String = ""
    @FocusState private var isInputFocused: Bool

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if entries.isEmpty {
                emptyState
            } else {
                entryList
            }

            Divider()
            inputBar
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundStyle(DesignSystem.Colors.warmGray)

            Text("Try Explain Screenshot to get started")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.warmGray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignSystem.Spacing.xl)
    }

    // MARK: - Entry List

    private var entryList: some View {
        List(entries) { entry in
            entryRow(entry)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(
                    top: DesignSystem.Spacing.xs,
                    leading: DesignSystem.Spacing.md,
                    bottom: DesignSystem.Spacing.xs,
                    trailing: DesignSystem.Spacing.md
                ))
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Entry Row

    private func entryRow(_ entry: ConversationEntry) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            // Top: prompt + provider badge
            HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.prompt)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(entry.response)
                        .font(DesignSystem.Typography.callout)
                        .foregroundStyle(DesignSystem.Colors.warmGray)
                        .lineLimit(3)
                }

                Spacer(minLength: DesignSystem.Spacing.sm)

                VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
                    providerBadge(for: entry)
                    timestampLabel(for: entry)

                    Button("Re-run") {
                        onRerunEntry?(entry)
                    }
                    .font(DesignSystem.Typography.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(DesignSystem.Colors.forgeOrange)
                }
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func providerBadge(for entry: ConversationEntry) -> some View {
        Text(entry.providerType.uppercased())
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(DesignSystem.Colors.warmGray)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(DesignSystem.Colors.warmGray.opacity(0.15))
            )
    }

    private func timestampLabel(for entry: ConversationEntry) -> some View {
        Text(entry.timestamp, style: .relative)
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(DesignSystem.Colors.warmGray)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            TextField("Ask about this screenshot…", text: $newPromptText, axis: .vertical)
                .font(DesignSystem.Typography.body)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .focused($isInputFocused)
                .onSubmit { submitPrompt() }

            Button(action: submitPrompt) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(
                        newPromptText.trimmingCharacters(in: .whitespaces).isEmpty
                            ? DesignSystem.Colors.warmGray
                            : DesignSystem.Colors.forgeOrange
                    )
            }
            .buttonStyle(.plain)
            .disabled(newPromptText.trimmingCharacters(in: .whitespaces).isEmpty)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(DesignSystem.Spacing.md)
        .background(.ultraThinMaterial)
    }

    // MARK: - Actions

    private func submitPrompt() {
        let trimmed = newPromptText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onSubmitPrompt?(trimmed)
        newPromptText = ""
    }
}

// MARK: - Preview

#Preview("With entries") {
    let sampleEntries: [ConversationEntry] = [
        ConversationEntry(
            captureRecordID: UUID(),
            prompt: "Explain what's happening in this screenshot",
            response: "The screenshot shows a macOS settings panel with network configuration options. The user appears to be configuring a VPN connection.",
            providerType: "coreml",
            modelName: "Vision",
            tokenCount: 42,
            latencyMS: 320,
            timestamp: Date().addingTimeInterval(-120)
        ),
        ConversationEntry(
            captureRecordID: UUID(),
            prompt: "What errors can you see?",
            response: "There are no visible errors in this screenshot. The interface appears to be in a normal state.",
            providerType: "openai",
            modelName: "gpt-4o",
            tokenCount: 28,
            latencyMS: 1200,
            timestamp: Date().addingTimeInterval(-60)
        )
    ]

    ConversationHistoryView(
        entries: sampleEntries,
        onSubmitPrompt: { print("Prompt: \($0)") },
        onRerunEntry: { print("Re-run: \($0.prompt)") }
    )
    .frame(width: 420, height: 500)
}

#Preview("Empty state") {
    ConversationHistoryView(entries: [])
        .frame(width: 420, height: 300)
}
