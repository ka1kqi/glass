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

    /// Pointer offset from the frame origin while dragging, screen coords.
    private var dragOffset: NSPoint?
    /// Recent (timestamp, origin) samples for the release velocity.
    private var dragSamples: [(time: TimeInterval, origin: NSPoint)] = []

    override func mouseDown(with event: NSEvent) {
        let mouse = NSEvent.mouseLocation
        dragOffset = NSPoint(x: mouse.x - frame.origin.x, y: mouse.y - frame.origin.y)
        dragSamples = [(event.timestamp, frame.origin)]
    }

    override func mouseDragged(with event: NSEvent) {
        guard let offset = dragOffset else { return }
        let mouse = NSEvent.mouseLocation
        setFrameOrigin(NSPoint(x: mouse.x - offset.x, y: mouse.y - offset.y))
        dragSamples.append((event.timestamp, frame.origin))
        if dragSamples.count > 8 { dragSamples.removeFirst(dragSamples.count - 8) }
    }

    override func mouseUp(with event: NSEvent) {
        guard dragOffset != nil else { return }
        dragOffset = nil
        let velocity = Self.releaseVelocity(from: dragSamples)
        dragSamples = []
        onDragEnded?(velocity)
    }

    /// Velocity over the last ~120ms of samples, so pausing mid-drag
    /// before releasing kills the toss.
    static func releaseVelocity(from samples: [(time: TimeInterval, origin: NSPoint)]) -> CGVector {
        guard let last = samples.last else { return .zero }
        let recent = samples.filter { $0.time >= last.time - 0.12 }
        guard let first = recent.first, last.time > first.time else { return .zero }
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
