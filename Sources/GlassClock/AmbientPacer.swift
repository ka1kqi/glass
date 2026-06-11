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

    private weak var window: NSWindow?
    private var screenAsleep = false

    /// Begins observing; call once after the panel exists.
    func start(window: NSWindow) {
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

    private func refresh() {
        reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let occluded = !(window?.occlusionState.contains(.visible) ?? true)
        paused = screenAsleep
            || occluded
            || ProcessInfo.processInfo.isLowPowerModeEnabled
            || reduceMotion
    }
}
