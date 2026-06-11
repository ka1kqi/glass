import AppKit

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
        guard scale != lastScale else { return }
        let crossedNatural = (lastScale - 1).sign != (scale - 1).sign
        let hitLimit = scale == ZoomModel.range.lowerBound
            || scale == ZoomModel.range.upperBound
        guard crossedNatural || hitLimit else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment, performanceTime: .now)
    }
}
