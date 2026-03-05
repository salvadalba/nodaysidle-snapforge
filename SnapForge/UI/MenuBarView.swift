import SwiftUI
import AppKit
import OSLog

private let logger = Logger(subsystem: "com.snapforge", category: "MenuBarView")

struct MenuBarView: View {
    @Environment(AppServices.self) private var appServices
    @Environment(\.openWindow) private var openWindow

    @State private var lastCaptureStatus: CaptureStatus?
    @State private var isRecording: Bool = false
    @State private var recordingType: CaptureType?  // .video or .gif

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.forgeOrange)
                Text("SnapForge")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.sm)

            // Status banner (shows after capture)
            if let status = lastCaptureStatus {
                StatusBanner(status: status)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.xs)
            }

            Divider()
                .padding(.horizontal, DesignSystem.Spacing.sm)

            // Capture actions
            VStack(spacing: 2) {
                MenuBarButton(title: "Screenshot", symbol: "camera", shortcut: "⌘⇧4") {
                    await performCapture { try await appServices.captureService.captureScreenshot(region: nil) }
                }

                MenuBarButton(title: "Scrolling Capture", symbol: "arrow.up.and.down.text.horizontal") {
                    await performCapture {
                        let screenFrame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
                        return try await appServices.captureService.captureScrolling(region: screenFrame)
                    }
                }

                MenuBarButton(
                    title: isRecording && recordingType == .video ? "Stop Recording" : "Screen Recording",
                    symbol: isRecording && recordingType == .video ? "stop.circle.fill" : "record.circle",
                    isDestructive: isRecording && recordingType == .video
                ) {
                    if isRecording && recordingType == .video {
                        await stopRecording()
                    } else {
                        await startRecording(codec: .h265, type: .video)
                    }
                }

                MenuBarButton(
                    title: isRecording && recordingType == .gif ? "Stop GIF" : "GIF Recording",
                    symbol: isRecording && recordingType == .gif ? "stop.circle.fill" : "photo.on.rectangle",
                    isDestructive: isRecording && recordingType == .gif
                ) {
                    if isRecording && recordingType == .gif {
                        await stopRecording()
                    } else {
                        await startRecording(codec: .gif, type: .gif)
                    }
                }

                MenuBarButton(title: "OCR Capture", symbol: "doc.text.viewfinder") {
                    await performCapture { try await appServices.captureService.captureOCRRegion(region: nil) }
                }
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
            .padding(.horizontal, DesignSystem.Spacing.sm)

            Divider()
                .padding(.horizontal, DesignSystem.Spacing.sm)

            // Library + Settings
            VStack(spacing: 2) {
                MenuBarButton(title: "Open Library", symbol: "photo.on.rectangle.angled", shortcut: "⌘L") {
                    openWindow(id: "library")
                }
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
            .padding(.horizontal, DesignSystem.Spacing.sm)

            Divider()
                .padding(.horizontal, DesignSystem.Spacing.sm)

            // Quit
            VStack(spacing: 2) {
                MenuBarButton(title: "Quit SnapForge", symbol: "xmark.circle", shortcut: "⌘Q", isDestructive: true) {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.bottom, DesignSystem.Spacing.sm)
        }
        .frame(width: 260)
        .background(.ultraThinMaterial)
    }

    // MARK: - Capture Pipeline

    /// The critical pipeline: capture → save to library → copy to clipboard → show feedback
    private func performCapture(_ capture: @escaping () async throws -> CaptureResult) async {
        do {
            // 1. Capture the screenshot
            let result = try await capture()

            // 2. Save to library (SwiftData + FTS5)
            _ = try await appServices.libraryService.save(result: result)
            logger.info("Capture saved to library: \(result.filePath)")

            // 3. Copy image to clipboard for immediate use
            copyToClipboard(filePath: result.filePath)

            // 4. Reset engine state so next capture works
            await appServices.captureService.resetToIdle()

            // 5. Show success feedback
            withAnimation(.easeInOut(duration: 0.25)) {
                lastCaptureStatus = .success(type: result.captureType)
            }
            // Auto-dismiss after 3 seconds
            Task {
                try? await Task.sleep(for: .seconds(3))
                withAnimation(.easeOut(duration: 0.3)) {
                    lastCaptureStatus = nil
                }
            }
        } catch {
            logger.error("Capture failed: \(error.localizedDescription)")
            // Reset engine on error too
            await appServices.captureService.resetToIdle()

            withAnimation(.easeInOut(duration: 0.25)) {
                lastCaptureStatus = .error(message: error.localizedDescription)
            }
            Task {
                try? await Task.sleep(for: .seconds(4))
                withAnimation(.easeOut(duration: 0.3)) {
                    lastCaptureStatus = nil
                }
            }
        }
    }

    private func copyToClipboard(filePath: String) {
        guard let image = NSImage(contentsOfFile: filePath) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        logger.info("Screenshot copied to clipboard")
    }

    // MARK: - Recording

    private func startRecording(codec: RecordingCodec, type: CaptureType) async {
        do {
            let config = RecordingConfig(codec: codec)
            try await appServices.captureService.startRecording(config: config)
            withAnimation(.easeInOut(duration: 0.2)) {
                isRecording = true
                recordingType = type
                lastCaptureStatus = nil
            }
            logger.info("Recording started: \(type.rawValue)")
        } catch {
            logger.error("Failed to start recording: \(error.localizedDescription)")
            withAnimation(.easeInOut(duration: 0.25)) {
                lastCaptureStatus = .error(message: error.localizedDescription)
            }
            Task {
                try? await Task.sleep(for: .seconds(4))
                withAnimation(.easeOut(duration: 0.3)) {
                    lastCaptureStatus = nil
                }
            }
        }
    }

    private func stopRecording() async {
        do {
            let result = try await appServices.captureService.stopRecording()

            _ = try await appServices.libraryService.save(result: result)
            logger.info("Recording saved to library: \(result.filePath)")

            copyToClipboard(filePath: result.filePath)
            await appServices.captureService.resetToIdle()

            withAnimation(.easeInOut(duration: 0.2)) {
                isRecording = false
                recordingType = nil
                lastCaptureStatus = .success(type: result.captureType)
            }
            Task {
                try? await Task.sleep(for: .seconds(3))
                withAnimation(.easeOut(duration: 0.3)) {
                    lastCaptureStatus = nil
                }
            }
        } catch {
            logger.error("Failed to stop recording: \(error.localizedDescription)")
            await appServices.captureService.resetToIdle()

            withAnimation(.easeInOut(duration: 0.2)) {
                isRecording = false
                recordingType = nil
                lastCaptureStatus = .error(message: error.localizedDescription)
            }
            Task {
                try? await Task.sleep(for: .seconds(4))
                withAnimation(.easeOut(duration: 0.3)) {
                    lastCaptureStatus = nil
                }
            }
        }
    }
}

// MARK: - CaptureStatus

private enum CaptureStatus: Equatable {
    case success(type: CaptureType)
    case error(message: String)
}

// MARK: - StatusBanner

private struct StatusBanner: View {
    let status: CaptureStatus

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(iconColor)
            Text(message)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, 6)
        .background(
            backgroundColor.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
    }

    private var icon: String {
        switch status {
        case .success: return "checkmark.circle.fill"
        case .error:   return "exclamationmark.triangle.fill"
        }
    }

    private var iconColor: Color {
        switch status {
        case .success: return .green
        case .error:   return .red
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .success: return .green
        case .error:   return .red
        }
    }

    private var message: String {
        switch status {
        case .success(let type): return "\(type.rawValue.capitalized) captured & copied"
        case .error(let msg):    return msg
        }
    }
}

// MARK: - MenuBarButton

private struct MenuBarButton: View {
    let title: String
    let symbol: String
    var shortcut: String? = nil
    var isDestructive: Bool = false
    let action: () async -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(isDestructive ? .red : .primary)
                    .frame(width: 20, alignment: .center)
                Text(title)
                    .font(DesignSystem.Typography.callout)
                    .foregroundStyle(isDestructive ? .red : .primary)
                Spacer()
                if let shortcut {
                    Text(shortcut)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
