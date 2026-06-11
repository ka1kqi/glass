import SwiftUI

/// A one-shot diagonal light sweep across the glass, fired each time the
/// displayed time changes — a visual tick. Never loops.
struct MinuteGlintOverlay: View {
    /// The time string; any change fires one sweep.
    var trigger: String
    /// False under Reduce Motion.
    var enabled: Bool
    var cornerRadius: CGFloat

    /// 0 = sweep parked off the leading edge, 2 = parked off the trailing
    /// edge (the resting state).
    @State private var phase: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            let travel = geo.size.width + geo.size.height
            Rectangle()
                .fill(LinearGradient(
                    colors: [.clear, .white.opacity(0.08), .clear],
                    startPoint: .leading, endPoint: .trailing))
                .frame(width: geo.size.width * 0.45, height: travel * 2)
                .rotationEffect(.degrees(45))
                .blur(radius: 6)
                .position(x: phase * travel - travel / 2, y: geo.size.height / 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .allowsHitTesting(false)
        .onChange(of: trigger) {
            guard enabled else { return }
            // Jump to the start without animating, then sweep across.
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) { phase = 0 }
            withAnimation(.easeInOut(duration: 0.65)) { phase = 2 }
        }
    }
}
