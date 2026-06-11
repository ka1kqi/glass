import AppKit
import Combine

/// Single source of truth for whether ambient animation should run.
/// Everything animated takes `paused` as its TimelineView pause flag, so
/// the whole app goes quiet from one place.
@MainActor
final class AmbientPacer: ObservableObject {
    @Published private(set) var paused = false
    /// Reduce Motion also pauses, but glint/toss need it separately.
    @Published private(set) var reduceMotion = false
    /// Audio-feature gate: only sleep and Low Power Mode silence sound —
    /// occlusion and Reduce Motion are visual concerns.
    @Published private(set) var audioPaused = false

    private weak var window: NSWindow?
    private var screenAsleep = false
    private var dragging = false

    /// Begins observing; call once after the panel exists.
    func start(window: NSWindow) {
        guard self.window == nil else { return }  // observers register once
        self.window = window
        let center = NotificationCenter.default
        let workspace = NSWorkspace.shared.notificationCenter

        center.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: window, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.refresh() } }

        // Both screen sleep and full system sleep stop the show; either
        // wake notification restarts it.
        let sleepers: [(Notification.Name, Bool)] = [
            (NSWorkspace.screensDidSleepNotification, true),
            (NSWorkspace.screensDidWakeNotification, false),
            (NSWorkspace.willSleepNotification, true),
            (NSWorkspace.didWakeNotification, false),
        ]
        for (name, asleep) in sleepers {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.screenAsleep = asleep
                    self?.refresh()
                }
            }
        }

        center.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.refresh() } }

        workspace.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.refresh() } }

        refresh()
    }

    /// Rests the effects while the user drags the panel, keeping the main
    /// thread clear for move events.
    func setDragging(_ flag: Bool) {
        guard flag != dragging else { return }
        dragging = flag
        refresh()
    }

    private func refresh() {
        reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let occluded = !(window?.occlusionState.contains(.visible) ?? true)
        audioPaused = screenAsleep || ProcessInfo.processInfo.isLowPowerModeEnabled
        paused = screenAsleep
            || occluded
            || dragging
            || ProcessInfo.processInfo.isLowPowerModeEnabled
            || reduceMotion
    }
}
