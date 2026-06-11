import Foundation
import CoreGraphics

/// Pure math for settling the panel onto nearby screen edges.
public enum SnapBehavior {
    public static let threshold: CGFloat = 24

    /// If `frame` sits within `threshold` of an edge of `visibleFrame`
    /// (checked per axis, so corners snap on both), returns the origin
    /// that puts it flush against those edges; nil when nothing is close.
    /// When a panel is so large that both edges of one axis are within
    /// threshold, the left/bottom edge wins.
    public static func snappedOrigin(
        for frame: CGRect,
        in visibleFrame: CGRect,
        threshold: CGFloat = SnapBehavior.threshold
    ) -> CGPoint? {
        var origin = frame.origin
        var snapped = false
        if abs(frame.minX - visibleFrame.minX) <= threshold {
            origin.x = visibleFrame.minX
            snapped = true
        } else if abs(frame.maxX - visibleFrame.maxX) <= threshold {
            origin.x = visibleFrame.maxX - frame.width
            snapped = true
        }
        if abs(frame.minY - visibleFrame.minY) <= threshold {
            origin.y = visibleFrame.minY
            snapped = true
        } else if abs(frame.maxY - visibleFrame.maxY) <= threshold {
            origin.y = visibleFrame.maxY - frame.height
            snapped = true
        }
        return snapped ? origin : nil
    }
}
