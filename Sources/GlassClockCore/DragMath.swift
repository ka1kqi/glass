import Foundation

/// Pure math for the panel's toss gesture.
public enum DragMath {
    /// Velocity over the last `window` seconds before release. Filtering
    /// against the release timestamp (not the last drag sample) means a
    /// flick followed by a motionless hold releases with zero velocity.
    public static func releaseVelocity(
        samples: [(time: TimeInterval, origin: CGPoint)],
        releasedAt upTime: TimeInterval,
        window: TimeInterval = 0.12
    ) -> CGVector {
        let recent = samples.filter { $0.time >= upTime - window }
        guard let first = recent.first, let last = recent.last,
              last.time > first.time else { return .zero }
        let dt = last.time - first.time
        return CGVector(
            dx: (last.origin.x - first.origin.x) / dt,
            dy: (last.origin.y - first.origin.y) / dt)
    }
}
