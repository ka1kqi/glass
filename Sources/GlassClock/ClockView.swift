import SwiftUI
import GlassClockCore

struct ClockView: View {
    @ObservedObject var model: ClockModel

    var body: some View {
        Text(model.timeString)
            .font(.system(size: 88, weight: .medium, design: .rounded))
            .foregroundStyle(.primary)
            .frame(width: 340, height: 150)
            .background(VisualEffectBackground())
    }
}
