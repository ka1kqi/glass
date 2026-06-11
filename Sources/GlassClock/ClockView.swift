import SwiftUI
import GlassClockCore

struct ClockView: View {
    /// Size of the panel at 1x zoom; everything scales from here.
    static let baseSize = NSSize(width: 340, height: 150)

    @ObservedObject var model: ClockModel
    @ObservedObject var zoom: ZoomModel
    @ObservedObject var design: DesignModel
    @ObservedObject var pacer: AmbientPacer
    /// Panel frame in screen coordinates, for the cursor-lit rim.
    var windowFrame: () -> NSRect? = { nil }

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
                MinuteGlintOverlay(
                    trigger: model.timeString,
                    enabled: !pacer.reduceMotion,
                    cornerRadius: radius)
            }
            .overlay {
                SpecularRimOverlay(
                    paused: pacer.paused,
                    cornerRadius: radius,
                    windowFrame: windowFrame)
            }
    }
}
