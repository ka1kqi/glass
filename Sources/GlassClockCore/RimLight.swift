import Foundation

/// Pure math for the cursor-lit rim: which way the light points and how
/// strong it is. Full strength within ~150pt of the rim, gone past 600pt.
public enum RimLight {
    /// Angle (SwiftUI radians, y down) toward the cursor and a 0–1
    /// intensity from its distance to the rim. Inputs in screen
    /// coordinates (y up).
    public static func compute(
        panel: CGRect?, mouse: CGPoint
    ) -> (angle: Double, intensity: Double) {
        guard let panel else { return (0, 0) }
        let dx = mouse.x - panel.midX
        let dy = mouse.y - panel.midY
        let centerDistance = (dx * dx + dy * dy).squareRoot()
        let halfDiagonal = (panel.width * panel.width + panel.height * panel.height)
            .squareRoot() / 2
        let rimDistance = max(0, centerDistance - halfDiagonal)
        let intensity = max(0, 1 - max(0, rimDistance - 150) / 450)
        // Screen coordinates are y-up; SwiftUI angles are y-down.
        return (atan2(-dy, dx), Double(intensity))
    }
}
