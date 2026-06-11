import SwiftUI
import AppKit
import GlassClockCore

/// A constant night field with a moon glow that follows the real lunar
/// illumination and a slow tidal swell — render-server animation, one
/// moon-brightness commit per minute.
struct LunarTideLayer: NSViewRepresentable {
    var paused: Bool
    func makeNSView(context: Context) -> LunarTideView { LunarTideView() }
    func updateNSView(_ view: LunarTideView, context: Context) {
        view.setPaused(paused)
    }
}

final class LunarTideView: NSView {
    private let base = CAGradientLayer()
    private let moon = CALayer()
    private let swell = CALayer()
    private var refreshTimer: Timer?
    private var driftSize = NSSize.zero
    private var isPaused = false

    /// A soft radial glow, baked once.
    private static let moonGlow: CGImage = {
        let size = 256
        let space = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil, width: size, height: size,
            bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let gradient = CGGradient(
            colorsSpace: space,
            colors: [
                CGColor(red: 1, green: 1, blue: 1, alpha: 0.9),
                CGColor(red: 0.85, green: 0.9, blue: 1, alpha: 0.25),
                CGColor(red: 0.85, green: 0.9, blue: 1, alpha: 0),
            ] as CFArray,
            locations: [0, 0.35, 1])!
        let center = CGPoint(x: size / 2, y: size / 2)
        context.drawRadialGradient(
            gradient, startCenter: center, startRadius: 0,
            endCenter: center, endRadius: CGFloat(size) / 2, options: [])
        return context.makeImage()!
    }()

    /// A wide horizontal luminous band, baked once.
    private static let swellBand: CGImage = {
        let width = 256, height = 64
        let space = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let gradient = CGGradient(
            colorsSpace: space,
            colors: [
                CGColor(red: 0.7, green: 0.8, blue: 1, alpha: 0),
                CGColor(red: 0.7, green: 0.8, blue: 1, alpha: 0.5),
                CGColor(red: 0.7, green: 0.8, blue: 1, alpha: 0),
            ] as CFArray,
            locations: [0, 0.5, 1])!
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: height / 2),
            end: CGPoint(x: width, y: height / 2), options: [])
        return context.makeImage()!
    }()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = true
        base.startPoint = CGPoint(x: 0.5, y: 1)
        base.endPoint = CGPoint(x: 0.5, y: 0)
        base.colors = LunarPalette.field.map {
            NSColor(red: $0.red, green: $0.green, blue: $0.blue, alpha: 1).cgColor
        }
        layer?.addSublayer(base)
        swell.contents = Self.swellBand
        swell.contentsGravity = .resize
        swell.compositingFilter = "screenBlendMode"
        swell.opacity = 0.18
        layer?.addSublayer(swell)
        moon.contents = Self.moonGlow
        moon.contentsGravity = .resize
        layer?.addSublayer(moon)
        applyMoon(animated: false)
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.applyMoon(animated: true) }
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
        let moonDiameter = min(size.width, size.height) * 0.9
        moon.bounds = CGRect(x: 0, y: 0, width: moonDiameter, height: moonDiameter)
        moon.position = CGPoint(x: size.width * 0.74, y: size.height * 0.68)
        swell.bounds = CGRect(x: 0, y: 0, width: size.width * 1.5, height: size.height * 0.4)
        swell.position = CGPoint(x: size.width / 2, y: size.height * 0.22)
        CATransaction.commit()
        if abs(size.width - driftSize.width) > 1 || abs(size.height - driftSize.height) > 1 {
            driftSize = size
            restartDrift()
        }
    }

    /// The moon's brightness follows the real illuminated fraction.
    private func applyMoon(animated: Bool) {
        guard !(isPaused && animated) else { return }
        let illumination = LunarPhase.illumination(at: Date())
        CATransaction.begin()
        if animated {
            CATransaction.setAnimationDuration(2)
        } else {
            CATransaction.setDisableActions(true)
        }
        moon.opacity = Float(0.2 + 0.5 * illumination)
        CATransaction.commit()
    }

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
        let w = driftSize.width
        moon.removeAllAnimations()
        swell.removeAllAnimations()
        moon.add(wander("transform.translation.x", from: -w * 0.02, to: w * 0.02, over: 53), forKey: "x")
        swell.add(wander("transform.translation.x", from: -w * 0.25, to: w * 0.25, over: 41), forKey: "x")
    }

    func setPaused(_ paused: Bool) {
        guard paused != isPaused, let layer else { return }
        isPaused = paused
        if paused {
            LayerClock.pause(layer)
        } else {
            LayerClock.resume(layer)
            applyMoon(animated: false)
        }
    }
}
