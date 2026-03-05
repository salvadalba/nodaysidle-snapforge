import AppKit
import SwiftUI

// MARK: - CommandPalettePanel

/// Floating NSPanel that hosts `CommandPaletteView`.
/// Uses `.nonactivatingPanel` so it never steals focus from the active app.
final class CommandPalettePanel: NSPanel {

    // MARK: - Properties

    private var hostingView: NSHostingView<CommandPaletteView>?
    private var onSelect: ((CaptureType) -> Void)?

    // MARK: - Init

    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: style,
            backing: backingStoreType,
            defer: flag
        )
        configure()
    }

    // MARK: - Factory

    static func makePanel(onSelect: @escaping (CaptureType) -> Void) -> CommandPalettePanel {
        let panelRect = NSRect(x: 0, y: 0, width: 380, height: 280)
        let style: NSWindow.StyleMask = [
            .nonactivatingPanel,
            .titled,
            .fullSizeContentView
        ]

        let panel = CommandPalettePanel(
            contentRect: panelRect,
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        panel.onSelect = onSelect
        panel.installContentView(onSelect: onSelect)
        return panel
    }

    // MARK: - Configuration

    private func configure() {
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
    }

    private func installContentView(onSelect: @escaping (CaptureType) -> Void) {
        let view = CommandPaletteView(
            onSelect: { [weak self] type in
                onSelect(type)
                self?.dismiss()
            },
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 380, height: 280)
        self.hostingView = hosting
        self.contentView = hosting
    }

    // MARK: - Presentation

    func present(relativeTo screen: NSScreen? = nil) {
        let targetScreen = screen ?? NSScreen.main ?? NSScreen.screens.first
        if let screenFrame = targetScreen?.visibleFrame {
            let x = screenFrame.midX - frame.width / 2
            let y = screenFrame.midY - frame.height / 2
            setFrameOrigin(NSPoint(x: x, y: y))
        }
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismiss() {
        orderOut(nil)
    }

    // MARK: - NSPanel Overrides

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // MARK: - Keyboard Events

    override func keyDown(with event: NSEvent) {
        // Let SwiftUI's onKeyPress handle navigation; pass unhandled events to super.
        super.keyDown(with: event)
    }
}
