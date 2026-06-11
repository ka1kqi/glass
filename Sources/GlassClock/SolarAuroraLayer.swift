import SwiftUI
import AppKit
import GlassClockCore

/// The aurora as a Core Animation layer: mesh + grain rasterized once a
/// minute (a single commit), with the drift running as repeating
/// render-server transform animations — the app burns no CPU between
/// palette refreshes. (The previous TimelineView+MeshGradient version
/// re-rasterized the visually static field 15×/s, ~15% CPU at idle.)
struct SolarAuroraLayer: NSViewRepresentable {
    var paused: Bool

    /// Resolved once per launch. Crossing timezones mid-run shifts the
    /// palette until relaunch — acceptable for ambient decoration.
    /// Internal: the rim tints and the Caustics design sample the same place.
    static let location = TimeZoneLocation.coordinates()

    func makeNSView(context: Context) -> AuroraDriftView { AuroraDriftView() }

    func updateNSView(_ view: AuroraDriftView, context: Context) {
        view.setPaused(paused)
    }
}

/// Hosts one oversized aurora image layer whose slow pan-and-breathe is
/// pure render-server animation.
final class AuroraDriftView: NSView {
    private let aurora = CALayer()
    private var refreshTimer: Timer?
    private var settleTask: Task<Void, Never>?
    private var renderedSize = NSSize.zero
    private var isPaused = false

    /// Slightly irregular fixed mesh points; the motion comes from the
    /// layer transform, not from morphing the field.
    private static let meshPoints: [SIMD2<Float>] = [
        SIMD2(0, 0), SIMD2(0.55, 0), SIMD2(1, 0),
        SIMD2(0, 0.45), SIMD2(0.62, 0.55), SIMD2(1, 0.5),
        SIMD2(0, 1), SIMD2(0.45, 1), SIMD2(1, 1),
    ]

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = true
        aurora.contentsGravity = .resize
        layer?.addSublayer(aurora)
        // The palette slides imperceptibly; once a minute is plenty.
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.renderAurora(crossfade: true) }
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    required init?(coder: NSCoder) { fatalError("unused") }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        // Leaving the window (design switch) is this view's end of life;
        // stop the palette timer here — deinit can't touch it in Swift 6.
        if newWindow == nil {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }

    override func layout() {
        super.layout()
        let size = bounds.size
        guard size.width > 0, size.height > 0 else { return }
        // Disable implicit actions: with the layer clock frozen (paused),
        // an implicit bounds animation would stall at its first frame and
        // leave the aurora at stale geometry forever.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // Oversized so the drift never reveals an edge (max excursion is
        // ~6% translate + 4% scale against a 30% overhang per side).
        aurora.bounds = CGRect(x: 0, y: 0, width: size.width * 1.6, height: size.height * 1.6)
        aurora.position = CGPoint(x: size.width / 2, y: size.height / 2)
        CATransaction.commit()
        guard abs(size.width - renderedSize.width) > 1
            || abs(size.height - renderedSize.height) > 1 else { return }
        renderedSize = size
        if aurora.contents == nil {
            // First layout: draw immediately so launch never shows a gap.
            renderAurora(crossfade: false)
            restartDrift()
        } else {
            // Live zoom: the stretched stale image covers the gesture;
            // rasterize once the size stops changing.
            settleTask?.cancel()
            settleTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard !Task.isCancelled, let self else { return }
                self.renderAurora(crossfade: false)
                self.restartDrift()
            }
        }
    }

    /// Rasterizes mesh + grain at the current solar palette. One small
    /// image render and one CA commit; everything else is coasting.
    private func renderAurora(crossfade: Bool) {
        guard renderedSize.width > 0, !(isPaused && crossfade) else { return }
        let elevation = SolarPosition.elevation(
            latitude: SolarAuroraLayer.location.latitude,
            longitude: SolarAuroraLayer.location.longitude,
            date: Date())
        let colors = AuroraPalette.colors(forElevation: elevation).map {
            Color(red: $0.red, green: $0.green, blue: $0.blue)
        }
        let size = CGSize(width: renderedSize.width * 1.6, height: renderedSize.height * 1.6)
        let renderer = ImageRenderer(content:
            MeshGradient(
                width: AuroraPalette.meshWidth,
                height: AuroraPalette.meshHeight,
                points: Self.meshPoints,
                colors: colors)
            // Stronger than the on-screen 4% because the whole layer is
            // composited at 20% opacity by the design.
            .overlay(GrainOverlay(opacity: 0.2))
            .frame(width: size.width, height: size.height))
        renderer.scale = window?.backingScaleFactor ?? 2
        guard let image = renderer.cgImage else { return }
        if crossfade {
            let fade = CABasicAnimation(keyPath: "contents")
            fade.fromValue = aurora.contents
            fade.toValue = image
            fade.duration = 2
            aurora.add(fade, forKey: "paletteCrossfade")
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        aurora.contents = image
        CATransaction.commit()
    }

    /// Repeating autoreversing wanders on mutually prime periods, so the
    /// drift never visibly repeats. Re-added on size change (amplitudes
    /// are in points); the phase restart is invisible at these speeds.
    private func restartDrift() {
        let dx = renderedSize.width * 0.06
        let dy = renderedSize.height * 0.05
        aurora.removeAnimation(forKey: "driftX")
        aurora.removeAnimation(forKey: "driftY")
        aurora.removeAnimation(forKey: "breathe")
        aurora.add(LayerClock.wander("transform.translation.x", from: -dx, to: dx, over: 23), forKey: "driftX")
        aurora.add(LayerClock.wander("transform.translation.y", from: -dy, to: dy, over: 29), forKey: "driftY")
        aurora.add(LayerClock.wander("transform.scale", from: 1.0, to: 1.04, over: 37), forKey: "breathe")
    }

    /// Freezes/resumes the render-server clock for this layer.
    func setPaused(_ paused: Bool) {
        guard paused != isPaused else { return }
        isPaused = paused
        if paused {
            LayerClock.pause(aurora)
        } else {
            LayerClock.resume(aurora)
            renderAurora(crossfade: false)  // catch the palette up
        }
    }
}
