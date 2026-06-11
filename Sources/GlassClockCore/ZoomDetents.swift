import Foundation

/// When a zoom change deserves a haptic tick.
public enum ZoomDetents {
    /// True when moving from `old` to `new` crosses (or lands exactly on)
    /// the natural 1.0× size, or arrives at either end of `range`.
    public static func shouldTick(
        from old: CGFloat, to new: CGFloat, range: ClosedRange<CGFloat>
    ) -> Bool {
        guard new != old else { return false }
        // Explicit comparisons, not .sign: (0).sign is .plus, which would
        // miss a descent landing exactly on 1.0.
        let crossedNatural = (old > 1 && new <= 1) || (old < 1 && new >= 1)
        let hitLimit = new == range.lowerBound || new == range.upperBound
        return crossedNatural || hitLimit
    }
}
