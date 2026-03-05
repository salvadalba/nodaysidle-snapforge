import SwiftUI

struct MenuBarView: View {
    @Environment(AppServices.self) private var appServices
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Button("Screenshot", systemImage: "camera") {
                Task { try? await appServices.captureService.captureScreenshot(region: nil) }
            }
            .keyboardShortcut("4", modifiers: [.command, .shift])

            Button("Scrolling Capture", systemImage: "arrow.up.and.down.text.horizontal") {
                Task { try? await appServices.captureService.captureScrolling(region: .zero) }
            }

            Button("Screen Recording", systemImage: "record.circle") {
                Task { try? await appServices.captureService.startRecording(config: RecordingConfig()) }
            }

            Button("GIF Recording", systemImage: "photo.on.rectangle") {
                Task { try? await appServices.captureService.startRecording(config: RecordingConfig(codec: .gif)) }
            }

            Button("OCR Capture", systemImage: "doc.text.viewfinder") {
                Task { try? await appServices.captureService.captureOCRRegion(region: nil) }
            }

            Divider()

            Button("Open Library", systemImage: "photo.on.rectangle.angled") {
                openWindow(id: "library")
            }
            .keyboardShortcut("l", modifiers: [.command])

            Divider()

            Button("Quit SnapForge") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(DesignSystem.Spacing.sm)
    }
}
