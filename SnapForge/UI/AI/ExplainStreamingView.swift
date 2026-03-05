import SwiftUI

// MARK: - ExplainStreamingView

/// Displays an AI text generation stream token by token.
/// Accumulates chunks into a growing response string and shows
/// a pulsing insertion-point indicator while streaming is active.
struct ExplainStreamingView: View {

    // MARK: - Configuration

    let stream: AsyncThrowingStream<String, Error>
    let providerName: String
    let onCancel: () -> Void

    // MARK: - State

    @State private var tokens: String = ""
    @State private var streamTask: Task<Void, Never>?
    @State private var isStreaming: Bool = false
    @State private var errorMessage: String?
    @State private var startDate: Date = Date()
    @State private var tokenCount: Int = 0

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {

            // MARK: Header row
            HStack(spacing: DesignSystem.Spacing.sm) {
                providerBadge
                Spacer()
                elapsedTimeLabel
                tokenCountLabel
                cancelButton
            }

            // MARK: Response text
            ScrollView {
                HStack(alignment: .bottom, spacing: 2) {
                    Text(tokens.isEmpty ? " " : tokens)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)

                    if isStreaming {
                        insertionPointDot
                    }
                }
                .padding(DesignSystem.Spacing.md)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // MARK: Error banner
            if let errorMessage {
                errorBanner(message: errorMessage)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task { await consumeStream() }
        .onDisappear { streamTask?.cancel() }
    }

    // MARK: - Subviews

    private var providerBadge: some View {
        Text(providerName)
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(DesignSystem.Colors.warmGray)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(
                Capsule()
                    .fill(DesignSystem.Colors.warmGray.opacity(0.15))
            )
    }

    private var elapsedTimeLabel: some View {
        TimelineView(.periodic(from: startDate, by: 1.0)) { context in
            let elapsed = Int(context.date.timeIntervalSince(startDate))
            Text("\(elapsed)s")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.warmGray)
                .monospacedDigit()
        }
    }

    private var tokenCountLabel: some View {
        Text("\(tokenCount) tokens")
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(DesignSystem.Colors.warmGray)
            .monospacedDigit()
    }

    private var cancelButton: some View {
        Button(action: cancel) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(DesignSystem.Colors.warmGray)
        }
        .buttonStyle(.plain)
        .opacity(isStreaming ? 1.0 : 0.3)
        .disabled(!isStreaming)
        .keyboardShortcut(.escape, modifiers: [])
    }

    private var insertionPointDot: some View {
        Circle()
            .fill(DesignSystem.Colors.sparkGold)
            .frame(width: 8, height: 8)
            .phaseAnimator([false, true]) { view, isVisible in
                view.opacity(isVisible ? 1.0 : 0.15)
            } animation: { _ in
                .easeInOut(duration: 0.55)
            }
            .padding(.bottom, 2)
    }

    private func errorBanner(message: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(.red)
            Spacer()
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.red.opacity(0.1))
        )
    }

    // MARK: - Stream Consumption

    private func consumeStream() async {
        isStreaming = true
        startDate = Date()
        tokens = ""
        tokenCount = 0
        errorMessage = nil

        do {
            for try await chunk in stream {
                tokens += chunk
                // Rough word-based token estimate (1 token ≈ 0.75 words).
                tokenCount = max(tokenCount, Int(Double(tokens.split(separator: " ").count) / 0.75))
            }
        } catch is CancellationError {
            // Normal cancellation — leave tokens as-is.
        } catch {
            if let aiError = error as? AIError {
                errorMessage = aiError.errorDescription ?? error.localizedDescription
            } else {
                errorMessage = error.localizedDescription
            }
        }

        isStreaming = false
    }

    private func cancel() {
        streamTask?.cancel()
        onCancel()
        isStreaming = false
    }
}

// MARK: - Preview

#Preview {
    let demoStream = AsyncThrowingStream<String, Error> { continuation in
        Task {
            let words = "SnapForge is a precision screen capture studio for macOS. It uses on-device AI to explain, annotate, and summarize everything you capture.".split(separator: " ")
            for word in words {
                try? await Task.sleep(for: .milliseconds(80))
                continuation.yield(String(word) + " ")
            }
            continuation.finish()
        }
    }

    ExplainStreamingView(
        stream: demoStream,
        providerName: "CoreML",
        onCancel: {}
    )
    .frame(width: 480, height: 320)
    .padding()
}
