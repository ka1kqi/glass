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

}
