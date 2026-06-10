import AppKit

/// Borderless glass panel that floats above all windows, on every Space
/// and over fullscreen apps, draggable from anywhere on its surface.
final class ClockPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Called with a multiplicative zoom factor when the user pinches or
    /// scrolls on the panel.
    var onZoom: ((CGFloat) -> Void)?

    override func magnify(with event: NSEvent) {
        onZoom?(clampedFactor(1 + event.magnification))
    }

    override func scrollWheel(with event: NSEvent) {
        onZoom?(clampedFactor(1 + event.scrollingDeltaY * 0.005))
    }

    /// Keeps one wild event (a flicked wheel, a jumpy pinch) from slamming
    /// the scale to its bounds in a single step.
    private func clampedFactor(_ factor: CGFloat) -> CGFloat {
        min(max(factor, 0.8), 1.25)
    }
}
