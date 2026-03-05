import AppKit
import SwiftUI

// MARK: - ActionBarWindow

/// HUD-style NSPanel that floats above other windows and hosts `ActionBarView`.
/// It uses `.nonactivatingPanel` to never steal focus from the captured content.
final class ActionBarWindow: NSPanel {

    // MARK: - Properties

    private var hostingView: NSHostingView<ActionBarView>?
    private(set) var captureType: CaptureType = .screenshot
    private var onAction: ((ActionType) -> Void)?

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

    static func makePanel(
        captureType: CaptureType,
        onAction: @escaping (ActionType) -> Void
    ) -> ActionBarWindow {
        let panelRect = NSRect(x: 0, y: 0, width: 440, height: 90)
        let style: NSWindow.StyleMask = [
            .nonactivatingPanel,
            .titled,
            .fullSizeContentView
        ]

        let panel = ActionBarWindow(
            contentRect: panelRect,
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        panel.captureType = captureType
        panel.onAction = onAction
        panel.installContentView(captureType: captureType, onAction: onAction)
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
        animationBehavior = .utilityWindow
    }

    private func installContentView(
        captureType: CaptureType,
        onAction: @escaping (ActionType) -> Void
    ) {
        let view = ActionBarView(captureType: captureType) { [weak self] action in
            onAction(action)
            if action == .delete || action == .copy {
                self?.dismiss(animated: true)
            }
        }
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 440, height: 90)
        self.hostingView = hosting
        self.contentView = hosting
    }

    // MARK: - Presentation

    /// Present the action bar just below the bottom-right corner of `anchorRect` (in screen coordinates).
    func present(below anchorRect: NSRect, on screen: NSScreen? = nil) {
        let targetScreen = screen ?? NSScreen.main ?? NSScreen.screens.first
        let screenFrame = targetScreen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        var origin = NSPoint(
            x: anchorRect.maxX - frame.width,
            y: anchorRect.minY - frame.height - 8
        )

        // Clamp to screen bounds
        origin.x = max(screenFrame.minX, min(origin.x, screenFrame.maxX - frame.width))
        origin.y = max(screenFrame.minY, origin.y)

        setFrameOrigin(origin)
        alphaValue = 0
        makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            animator().alphaValue = 1
        }
    }

    /// Present centered below the screen's visible area (fallback).
    func presentCentered(on screen: NSScreen? = nil) {
        let targetScreen = screen ?? NSScreen.main ?? NSScreen.screens.first
        let screenFrame = targetScreen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let origin = NSPoint(
            x: screenFrame.midX - frame.width / 2,
            y: screenFrame.minY + 60
        )
        setFrameOrigin(origin)
        alphaValue = 0
        makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            animator().alphaValue = 1
        }
    }

    func dismiss(animated: Bool = true) {
        guard animated else { orderOut(nil); return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            animator().alphaValue = 0
        } completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                self?.orderOut(nil)
                self?.alphaValue = 1
            }
        }
    }

    // MARK: - NSPanel Overrides

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
