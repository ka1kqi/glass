import AppKit
import Combine

/// Publishes the cursor-driven rim light, fed by mouse-move events
/// instead of a poll loop — the app does zero work while the cursor
/// rests. (The previous 15 fps TimelineView kept the window's display
/// cycle hot even when nothing on screen changed.)
@MainActor
final class RimLightModel: ObservableObject {
    /// Angle (SwiftUI radians, y down) toward the cursor.
    @Published private(set) var angle: Double = 0
    /// 0–1; quantized so sub-pixel mouse jitter doesn't re-render.
    @Published private(set) var intensity: Double = 0

    private weak var window: NSWindow?
    private var monitors: [Any] = []
    private var subscriptions: Set<AnyCancellable> = []
    private var lastRefresh: TimeInterval = 0
    private var gatedOff = false

    /// Begins watching mouse movement; call once after the panel exists.
    /// The light goes dark whenever the pacer pauses or the lighting
    /// toggle is off.
    func start(window: NSWindow, pacer: AmbientPacer, lighting: LightingModel) {
        guard self.window == nil else { return }
        self.window = window

        // The global monitor sees moves over other apps; the local one
        // covers moves (and the manual drag) over Glass itself.
        if let global = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged],
            handler: { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged], handler: { [weak self] event in
                Task { @MainActor in self?.refresh() }
                return event
            }) {
            monitors.append(local)
        }

        pacer.$paused.combineLatest(lighting.$isOn)
            .sink { [weak self] paused, lightingOn in
                Task { @MainActor in
                    guard let self else { return }
                    self.gatedOff = paused || !lightingOn
                    if self.gatedOff {
                        if self.intensity != 0 { self.intensity = 0 }
                    } else {
                        self.refresh(force: true)
                    }
                }
            }
            .store(in: &subscriptions)
    }

    /// Re-aims the light after the panel itself moves under a stationary
    /// cursor (toss settle, zoom resize) — there's no mouse event then.
    func nudge() {
        refresh(force: true)
    }

    private func refresh(force: Bool = false) {
        guard !gatedOff else { return }
        // ~30 Hz ceiling while the mouse moves; nothing at all otherwise.
        let now = ProcessInfo.processInfo.systemUptime
        guard force || now - lastRefresh >= 1.0 / 30.0 else { return }
        lastRefresh = now
        guard let frame = window?.frame else { return }
        let light = SpecularRimOverlay.light(panel: frame, mouse: NSEvent.mouseLocation)
        // Quantize (~1.3° and 0.02 steps — invisible) so a cursor sweeping
        // far across the desktop doesn't publish redundant frames.
        let quantizedIntensity = (light.intensity * 50).rounded() / 50
        let quantizedAngle = (light.angle * 45).rounded() / 45
        if quantizedIntensity != intensity { intensity = quantizedIntensity }
        if quantizedIntensity > 0, quantizedAngle != angle { angle = quantizedAngle }
    }
}
