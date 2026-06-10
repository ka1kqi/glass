import SwiftUI
import GlassClockCore

struct ClockView: View {
    /// Size of the panel at 1x zoom; everything scales from here.
    static let baseSize = NSSize(width: 340, height: 150)

    @ObservedObject var model: ClockModel
    @ObservedObject var zoom: ZoomModel

    var body: some View {
        Text(model.timeString)
            .font(.system(size: 88 * zoom.scale, weight: .medium, design: .rounded))
            .foregroundStyle(.primary)
            .frame(width: Self.baseSize.width * zoom.scale,
                   height: Self.baseSize.height * zoom.scale)
            .background(VisualEffectBackground(cornerRadius: 24 * zoom.scale))
    }
}
