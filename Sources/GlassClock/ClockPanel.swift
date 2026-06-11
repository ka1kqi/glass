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
        // Dragging is manual (mouseDown/Dragged/Up below) so release
        // velocity can drive the toss glide.
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Called with a multiplicative zoom factor when the user pinches or
    /// scrolls on the panel.
    var onZoom: ((CGFloat) -> Void)?

    /// Called when a drag ends, with the release velocity in points/sec
    /// (screen coordinates, y up).
    var onDragEnded: ((CGVector) -> Void)?

    /// Called with true on the first real movement of a drag and false on
    /// release, so effects can rest while the panel is in motion. Plain
    /// clicks never fire it.
    var onDraggingChanged: ((Bool) -> Void)?

    /// Called on right-click (or control-click) to show the app menu.
    var onContextClick: ((NSEvent) -> Void)?

    /// Pointer offset from the frame origin while dragging, screen coords.
    private var dragOffset: NSPoint?
    /// Recent (timestamp, origin) samples for the release velocity.
    private var dragSamples: [(time: TimeInterval, origin: NSPoint)] = []

    override func mouseDown(with event: NSEvent) {
        // At normal level (Float Above Windows off) a click brings the
        // clock back in front of whatever covered it.
        if level == .normal { orderFront(nil) }
        let mouse = NSEvent.mouseLocation
        dragOffset = NSPoint(x: mouse.x - frame.origin.x, y: mouse.y - frame.origin.y)
        dragSamples = [(event.timestamp, frame.origin)]
    }

    override func mouseDragged(with event: NSEvent) {
        guard let offset = dragOffset else { return }
        if dragSamples.count == 1 { onDraggingChanged?(true) }
        let mouse = NSEvent.mouseLocation
        setFrameOrigin(NSPoint(x: mouse.x - offset.x, y: mouse.y - offset.y))
        dragSamples.append((event.timestamp, frame.origin))
        if dragSamples.count > 8 { dragSamples.removeFirst(dragSamples.count - 8) }
    }

    override func mouseUp(with event: NSEvent) {
        guard dragOffset != nil else { return }
        dragOffset = nil
        // A plain click (no mouseDragged samples) must not nudge the panel.
        guard dragSamples.count > 1 else { dragSamples = []; return }
        onDraggingChanged?(false)
        let velocity = Self.releaseVelocity(from: dragSamples, releasedAt: event.timestamp)
        dragSamples = []
        onDragEnded?(velocity)
    }

    /// Routes left-mouse events straight to the drag handlers instead of
    /// relying on the hosting view to leave them unhandled — the whole
    /// panel surface is a drag region, like isMovableByWindowBackground.
    /// Right-click (and the control-click idiom) opens the app menu.
    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown where event.modifierFlags.contains(.control):
            onContextClick?(event)
        case .leftMouseDown: mouseDown(with: event)
        case .leftMouseDragged: mouseDragged(with: event)
        case .leftMouseUp: mouseUp(with: event)
        case .rightMouseDown: onContextClick?(event)
        default: super.sendEvent(event)
        }
    }

    /// Velocity over the last ~120ms before release. Filtering against the
    /// release timestamp (not the last drag sample) means a flick followed
    /// by a motionless hold releases with zero velocity.
    static func releaseVelocity(
        from samples: [(time: TimeInterval, origin: NSPoint)],
        releasedAt upTime: TimeInterval
    ) -> CGVector {
        let recent = samples.filter { $0.time >= upTime - 0.12 }
        guard let first = recent.first, let last = recent.last,
              last.time > first.time else { return .zero }
        let dt = last.time - first.time
        return CGVector(
            dx: (last.origin.x - first.origin.x) / dt,
            dy: (last.origin.y - first.origin.y) / dt)
    }

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
