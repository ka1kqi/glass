import SwiftUI
import GlassClockCore

struct ClockView: View {
    /// Size of the panel at 1x zoom; everything scales from here.
    static let baseSize = NSSize(width: 340, height: 150)

    @ObservedObject var model: ClockModel
    @ObservedObject var zoom: ZoomModel
    @ObservedObject var design: DesignModel
    @ObservedObject var pacer: AmbientPacer
    @ObservedObject var lighting: LightingModel
    /// Deliberately NOT @ObservedObject: only SpecularRimOverlay reads the
    /// published values, and observing here would re-run this whole body
    /// at up to 30Hz while the cursor moves.
    let rim: RimLightModel

    var body: some View {
        let radius = 24 * zoom.scale
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        Text(model.timeString)
            .font(.system(size: 88 * zoom.scale, weight: .medium, design: .rounded))
            .foregroundStyle(.primary)
            .frame(width: Self.baseSize.width * zoom.scale,
                   height: Self.baseSize.height * zoom.scale)
            .background {
                ZStack {
                    VisualEffectBackground(cornerRadius: radius)
                    design.current.ambientLayer(paused: pacer.paused)
                        .clipShape(shape)
                        .id(design.designID)        // new identity per design…
                        .transition(.opacity)        // …so switching cross-fades
                }
                .animation(.easeInOut(duration: 0.4), value: design.designID)
            }
            .overlay {
                if lighting.isOn {
                    MinuteGlintOverlay(
                        trigger: model.timeString,
                        enabled: !pacer.paused,   // paused subsumes Reduce Motion
                        cornerRadius: radius)
                }
            }
            .overlay {
                // The rim model is gated by pacer + lighting, so the arc
                // pins to zero (plain hairline) whenever effects are off.
                // The tint refreshes when the minute tick re-runs body.
                SpecularRimOverlay(
                    light: rim,
                    cornerRadius: radius,
                    tint: design.current.rimTint(at: Date()))
            }
    }
}
