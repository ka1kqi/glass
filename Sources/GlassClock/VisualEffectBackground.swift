import SwiftUI
import AppKit

/// The real macOS glass: blurs whatever is behind the window, adapting to
/// light/dark mode, with a continuous rounded-corner mask.
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        // .fullScreenUI has the lightest tint of the behind-window
        // materials, so more of what's underneath shows through.
        view.material = .fullScreenUI
        view.blendingMode = .behindWindow
        view.state = .active
        // Fade the material's frost so the glass reads nearly clear.
        view.alphaValue = 0.85
        view.wantsLayer = true
        view.layer?.cornerRadius = 24
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
