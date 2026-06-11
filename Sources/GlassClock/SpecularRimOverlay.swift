import SwiftUI
import AppKit

/// The panel's hairline rim plus a soft specular arc on the side facing
/// the mouse cursor, as if the cursor were a light source the glass
/// catches. Full strength within ~150pt of the rim, gone beyond ~600pt.
struct SpecularRimOverlay: View {
    var paused: Bool
    var cornerRadius: CGFloat
    /// Panel frame in screen coordinates (y up), polled per frame.
    var windowFrame: () -> NSRect?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: paused)) { _ in
            // When paused the timeline stops re-rendering — render the
            // plain hairline so a bright arc can't freeze on screen.
            let light = paused
                ? (angle: 0.0, intensity: 0.0)
                : Self.light(panel: windowFrame(), mouse: NSEvent.mouseLocation)
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            shape
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                .overlay {
                    if light.intensity > 0 {
                        shape.strokeBorder(
                            AngularGradient(
                                stops: [
                                    .init(color: .white.opacity(0.55 * light.intensity), location: 0),
                                    .init(color: .clear, location: 0.18),
                                    .init(color: .clear, location: 0.82),
                                    .init(color: .white.opacity(0.55 * light.intensity), location: 1),
                                ],
                                center: .center,
                                angle: .radians(light.angle)),
                            lineWidth: 1)
                    }
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
