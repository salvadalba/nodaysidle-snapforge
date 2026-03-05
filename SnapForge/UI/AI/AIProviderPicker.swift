import SwiftUI

// MARK: - AIProviderPicker

/// A SwiftUI Menu that lets the user choose the active AI inference provider.
/// Persists the last-selected provider via `@AppStorage`.
/// Shows a loading spinner when the selected provider is not yet ready.
struct AIProviderPicker: View {

    // MARK: - Input

    /// Called when the user picks a new provider.
    var onProviderSelected: ((ProviderType) -> Void)?

    // MARK: - Persistence

    @AppStorage("lastUsedProvider") private var lastUsedProviderRaw: String = ProviderType.coreml.rawValue

    // MARK: - State

    @State private var loadingProvider: ProviderType?

    // MARK: - Derived

    private var selectedProvider: ProviderType {
        ProviderType(rawValue: lastUsedProviderRaw) ?? .coreml
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Menu {
                ForEach(ProviderType.allCases, id: \.self) { provider in
                    Button(action: { select(provider) }) {
                        Label {
                            HStack {
                                Text(displayName(for: provider))
                                if modelName(for: provider).isEmpty == false {
                                    Text("– \(modelName(for: provider))")
                                        .foregroundStyle(DesignSystem.Colors.warmGray)
                                }
                            }
                        } icon: {
                            statusIcon(for: provider)
                        }
                    }
                }
            } label: {
                menuLabel
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            if loadingProvider != nil {
                ProgressView()
                    .scaleEffect(0.65)
                    .frame(width: 14, height: 14)
            }
        }
    }

    // MARK: - Menu Label

    private var menuLabel: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Circle()
                .fill(isLoaded(selectedProvider) ? Color.green : DesignSystem.Colors.warmGray)
                .frame(width: 8, height: 8)

            Text(displayName(for: selectedProvider))
                .font(DesignSystem.Typography.body)
                .foregroundStyle(.primary)

            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 10))
                .foregroundStyle(DesignSystem.Colors.warmGray)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Status Icon

    @ViewBuilder
    private func statusIcon(for provider: ProviderType) -> some View {
        Circle()
            .fill(isLoaded(provider) ? Color.green : DesignSystem.Colors.warmGray)
            .frame(width: 8, height: 8)
    }

    // MARK: - Actions

    private func select(_ provider: ProviderType) {
        guard provider != selectedProvider else { return }

        if !isLoaded(provider) {
            loadingProvider = provider
            // Simulate a brief load — in production the caller wires real load logic.
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                await MainActor.run {
                    loadingProvider = nil
                    lastUsedProviderRaw = provider.rawValue
                    onProviderSelected?(provider)
                }
            }
        } else {
            lastUsedProviderRaw = provider.rawValue
            onProviderSelected?(provider)
        }
    }

    // MARK: - Helpers

    private func displayName(for provider: ProviderType) -> String {
        switch provider {
        case .coreml:    return "CoreML"
        case .mlx:       return "MLX"
        case .ollama:    return "Ollama"
        case .openai:    return "OpenAI"
        case .anthropic: return "Anthropic"
        }
    }

    private func modelName(for provider: ProviderType) -> String {
        switch provider {
        case .coreml:    return "Vision"
        case .mlx:       return "Mistral-7B"
        case .ollama:    return "llama3"
        case .openai:    return "gpt-4o"
        case .anthropic: return "claude-3-5-sonnet"
        }
    }

    /// Returns whether the provider is currently loaded/ready.
    /// In production this would query ModelManagerService; here we
    /// treat local providers as always loaded and cloud providers as
    /// dependent on an API key being set.
    private func isLoaded(_ provider: ProviderType) -> Bool {
        switch provider {
        case .coreml, .mlx, .ollama: return true
        case .openai, .anthropic:    return false
        }
    }
}

// MARK: - Preview

#Preview {
    AIProviderPicker { provider in
        print("Selected: \(provider.rawValue)")
    }
    .padding()
    .background(.regularMaterial)
}
