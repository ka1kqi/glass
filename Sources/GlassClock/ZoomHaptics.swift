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
        // Explicit comparisons, not .sign: (0).sign is .plus, which would
        // miss a descent landing exactly on 1.0.
        let crossedNatural = (lastScale > 1 && scale <= 1) || (lastScale < 1 && scale >= 1)
        let hitLimit = scale == ZoomModel.range.lowerBound
            || scale == ZoomModel.range.upperBound
        guard crossedNatural || hitLimit else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment, performanceTime: .now)
    }
}
