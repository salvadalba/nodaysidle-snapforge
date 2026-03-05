import SwiftUI

struct SettingsView: View {
    @Environment(AppServices.self) private var appServices

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gear") }
            CaptureSettingsTab()
                .tabItem { Label("Capture", systemImage: "camera") }
            AISettingsTab()
                .tabItem { Label("AI", systemImage: "brain") }
            SharingSettingsTab()
                .tabItem { Label("Sharing", systemImage: "square.and.arrow.up") }
            AutomationSettingsTab()
                .tabItem { Label("Automation", systemImage: "gearshape.2") }
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - Reusable Settings Section

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(title)
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(.primary)

            VStack(spacing: DesignSystem.Spacing.sm) {
                content()
            }
            .padding(DesignSystem.Spacing.md)
            .glassCard()
        }
    }
}

struct GeneralSettingsTab: View {
    @AppStorage("captureShortcut") private var captureShortcut = "⌘⇧4"
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    var body: some View {
        Form {
            SettingsSection(title: "Startup") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
            }
            SettingsSection(title: "Shortcuts") {
                TextField("Global Shortcut", text: $captureShortcut)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .padding()
    }
}

struct CaptureSettingsTab: View {
    @AppStorage("defaultCaptureType") private var defaultCaptureType = "screenshot"
    @AppStorage("saveFormat") private var saveFormat = "png"

    var body: some View {
        Form {
            SettingsSection(title: "Defaults") {
                Picker("Default Capture Type", selection: $defaultCaptureType) {
                    Text("Screenshot").tag("screenshot")
                    Text("Region").tag("region")
                    Text("Scrolling").tag("scrolling")
                }
                Picker("Save Format", selection: $saveFormat) {
                    Text("PNG").tag("png")
                    Text("JPEG").tag("jpeg")
                    Text("TIFF").tag("tiff")
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .padding()
    }
}

struct AISettingsTab: View {
    @AppStorage("preferredAIProvider") private var preferredProvider = "coreml"
    @AppStorage("modelIdleTimeout") private var idleTimeout = 300.0

    var body: some View {
        Form {
            SettingsSection(title: "AI Engine") {
                Picker("Preferred Provider", selection: $preferredProvider) {
                    Text("Core ML").tag("coreml")
                    Text("MLX").tag("mlx")
                    Text("Ollama").tag("ollama")
                    Text("OpenAI").tag("openai")
                    Text("Anthropic").tag("anthropic")
                }
                TextField("Model Idle Timeout (seconds)", value: $idleTimeout, format: .number)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .padding()
    }
}

struct SharingSettingsTab: View {
    @AppStorage("privacyMode") private var privacyMode = "localOnly"

    var body: some View {
        Form {
            SettingsSection(title: "Privacy") {
                Picker("Privacy Mode", selection: $privacyMode) {
                    Text("Local Only").tag("localOnly")
                    Text("Upload").tag("upload")
                    Text("Ask Every Time").tag("askEveryTime")
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .padding()
    }
}

struct AutomationSettingsTab: View {
    @AppStorage("httpBridgeEnabled") private var httpBridgeEnabled = true
    @AppStorage("httpBridgePort") private var httpBridgePort = 48721

    var body: some View {
        Form {
            SettingsSection(title: "HTTP Bridge") {
                Toggle("Enable HTTP Bridge API", isOn: $httpBridgeEnabled)
                TextField("Port", value: $httpBridgePort, format: .number)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .padding()
    }
}
