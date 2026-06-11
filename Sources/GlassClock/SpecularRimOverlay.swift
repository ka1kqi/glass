import SwiftUI
import AppKit

/// The panel's hairline rim plus a soft specular arc on the side facing
/// the mouse cursor, as if the cursor were a light source the glass
/// catches. Full strength within ~150pt of the rim, gone beyond ~600pt.
/// Renders only when `RimLightModel` publishes a change — no poll loop.
struct SpecularRimOverlay: View {
    @ObservedObject var light: RimLightModel
    var cornerRadius: CGFloat
    /// Arc color; designs tint the reactive light to match their ambiance.
    var tint: Color

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .strokeBorder(.white.opacity(0.10), lineWidth: 1)
            .overlay {
                if light.intensity > 0 {
                    shape.strokeBorder(
                        AngularGradient(
                            stops: [
                                .init(color: tint.opacity(0.55 * light.intensity), location: 0),
                                .init(color: .clear, location: 0.18),
                                .init(color: .clear, location: 0.82),
                                .init(color: tint.opacity(0.55 * light.intensity), location: 1),
                            ],
                            center: .center,
                            angle: .radians(light.angle)),
                        lineWidth: 1)
                }
            }
            .allowsHitTesting(false)
    }

    /// Angle (SwiftUI radians, y down) toward the cursor and a 0–1
    /// intensity from its distance to the rim.
    static func light(panel: NSRect?, mouse: NSPoint) -> (angle: Double, intensity: Double) {
        guard let panel else { return (0, 0) }
        let dx = mouse.x - panel.midX
        let dy = mouse.y - panel.midY
        let centerDistance = (dx * dx + dy * dy).squareRoot()
        let halfDiagonal = (panel.width * panel.width + panel.height * panel.height).squareRoot() / 2
        let rimDistance = max(0, centerDistance - halfDiagonal)
        let intensity = max(0, 1 - max(0, rimDistance - 150) / 450)
        // Screen coordinates are y-up; SwiftUI angles are y-down.
        return (atan2(-dy, dx), Double(intensity))
    }
}
