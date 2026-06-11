import SwiftUI
import AppKit
import GlassClockCore

/// Sunlight through water: a solar-keyed water gradient with two
/// screen-blended caustic webs drifting over it — all render-server
/// animation, one palette commit per minute.
struct CausticsLayer: NSViewRepresentable {
    var paused: Bool
    func makeNSView(context: Context) -> CausticsSurfaceView { CausticsSurfaceView() }
    func updateNSView(_ view: CausticsSurfaceView, context: Context) {
        view.setPaused(paused)
    }
}

final class CausticsSurfaceView: NSView {
    private let base = CAGradientLayer()
    private let webA = CALayer()
    private let webB = CALayer()
    private var refreshTimer: Timer?
    private var driftSize = NSSize.zero
    private var isPaused = false

    /// One grayscale tile per web, baked once per launch.
    private static let tileA = tileImage(seed: 9)
    private static let tileB = tileImage(seed: 23)

    private static func tileImage(seed: UInt64) -> CGImage {
        let size = 256
        let bytes = CausticsTile.luminance(size: size, seed: seed)
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        return CGImage(
            width: size, height: size,
            bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: size,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider, decode: nil, shouldInterpolate: true,
            intent: .defaultIntent)!
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = true
        base.startPoint = CGPoint(x: 0.5, y: 1)   // layer coords: 1 = top
        base.endPoint = CGPoint(x: 0.5, y: 0)
        layer?.addSublayer(base)
        for (web, tile, opacity) in [(webA, Self.tileA, Float(0.5)),
                                     (webB, Self.tileB, Float(0.35))] {
            web.contents = tile
            web.contentsGravity = .resize
            web.compositingFilter = "screenBlendMode"
            web.opacity = opacity
            layer?.addSublayer(web)
        }
        applyPalette(animated: false)
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.applyPalette(animated: true) }
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    required init?(coder: NSCoder) { fatalError("unused") }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }

    override func layout() {
        super.layout()
        let size = bounds.size
        guard size.width > 0, size.height > 0 else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        base.frame = bounds
        // Webs are oversized so the drift never reveals an edge.
        for web in [webA, webB] {
            web.bounds = CGRect(x: 0, y: 0, width: size.width * 2, height: size.height * 2)
            web.position = CGPoint(x: size.width / 2, y: size.height / 2)
        }
        CATransaction.commit()
        if abs(size.width - driftSize.width) > 1 || abs(size.height - driftSize.height) > 1 {
            driftSize = size
            restartDrift()
        }
    }

    private func applyPalette(animated: Bool) {
        guard !(isPaused && animated) else { return }
        let elevation = SolarPosition.elevation(
            latitude: SolarAuroraLayer.location.latitude,
            longitude: SolarAuroraLayer.location.longitude,
            date: Date())
        let stops = CausticsPalette.colors(forElevation: elevation).map {
            NSColor(red: $0.red, green: $0.green, blue: $0.blue, alpha: 1).cgColor
        }
        CATransaction.begin()
        if animated {
            CATransaction.setAnimationDuration(2)
        } else {
            CATransaction.setDisableActions(true)
        }
        base.colors = stops
        CATransaction.commit()
    }

    /// Two webs wandering on mutually prime periods; their interference
    /// is the shimmer.
    private func restartDrift() {
        func wander(_ keyPath: String, from: Double, to: Double, over seconds: Double) -> CABasicAnimation {
            let animation = CABasicAnimation(keyPath: keyPath)
            animation.fromValue = from
            animation.toValue = to
            animation.duration = seconds
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            return animation
        }
        let w = driftSize.width, h = driftSize.height
        webA.removeAllAnimations()
        webB.removeAllAnimations()
        webA.add(wander("transform.translation.x", from: -w * 0.10, to: w * 0.10, over: 17), forKey: "x")
        webA.add(wander("transform.translation.y", from: -h * 0.06, to: h * 0.06, over: 26), forKey: "y")
        webB.add(wander("transform.translation.x", from: w * 0.08, to: -w * 0.08, over: 19), forKey: "x")
        webB.add(wander("transform.scale", from: 1.0, to: 1.15, over: 31), forKey: "breathe")
    }

    func setPaused(_ paused: Bool) {
        guard paused != isPaused, let layer else { return }
        isPaused = paused
        if paused {
            LayerClock.pause(layer)
        } else {
            LayerClock.resume(layer)
            applyPalette(animated: false)  // catch the water color up
        }
    }
}
