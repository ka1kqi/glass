import AppKit
import GlassClockCore

/// Trackpad ticks at meaningful zoom moments: crossing the natural 1.0×
/// size, and hitting either end of the zoom range.
@MainActor
struct ZoomHaptics {
    private var lastScale: CGFloat

    init(scale: CGFloat) {
        lastScale = scale
    }

    mutating func register(_ scale: CGFloat) {
        defer { lastScale = scale }
        guard ZoomDetents.shouldTick(from: lastScale, to: scale, range: ZoomModel.range)
        else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment, performanceTime: .now)
    }
}
