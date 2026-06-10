import AppKit
import Combine
import SwiftUI
import GlassClockCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: ClockPanel!
    private var statusItem: NSStatusItem!
    private let model = ClockModel()
    private let zoom = ZoomModel()
    private var zoomObserver: AnyCancellable?
    private let keepMacAwake = SleepPreventer.systemSleep()
    private let keepDisplayAwake = SleepPreventer.displaySleep()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if Installer.handOffToInstalledCopyIfNeeded() { return }
        NSApp.setActivationPolicy(.accessory)
        setUpPanel()
        setUpStatusItem()
        refreshOnWake()
    }

    private func setUpPanel() {
        panel = ClockPanel(contentRect: NSRect(origin: .zero, size: ClockView.baseSize))
        let hosting = NSHostingView(rootView: ClockView(model: model, zoom: zoom))
        // The panel's frame is driven exclusively by resizePanel(for:).
        // Without this, the hosting view's auto-layout constraints fight
        // every frame change (snapping it back top-left-anchored) until
        // SwiftUI re-renders, so zooming expands from a corner, not center.
        hosting.sizingOptions = []
        panel.contentView = hosting
        if !panel.setFrameUsingName("GlassClockPanel") || !isOnAnyScreen(panel.frame) {
            panel.center()
        }
        panel.setFrameAutosaveName("GlassClockPanel")
        panel.onZoom = { [zoom] factor in zoom.zoom(by: factor) }
        // Fires immediately with the persisted scale, which also normalizes
        // whatever size the frame autosave restored.
        zoomObserver = zoom.$scale.sink { [weak self] scale in
            self?.resizePanel(for: scale)
        }
        panel.orderFrontRegardless()
    }

    /// Resizes the panel around its center to match the zoom scale.
    private func resizePanel(for scale: CGFloat) {
        let newSize = NSSize(width: ClockView.baseSize.width * scale,
                             height: ClockView.baseSize.height * scale)
        var frame = panel.frame
        frame.origin.x -= (newSize.width - frame.width) / 2
        frame.origin.y -= (newSize.height - frame.height) / 2
        frame.size = newSize
        panel.setFrame(frame, display: true)
    }

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "clock", accessibilityDescription: "Glass")
        let menu = NSMenu()

        let macAwakeItem = NSMenuItem(
            title: "Keep Mac Awake",
            action: #selector(toggleKeepMacAwake(_:)),
            keyEquivalent: "")
        macAwakeItem.target = self
        macAwakeItem.state = keepMacAwake.isOn ? .on : .off
        macAwakeItem.toolTip = "Stops the Mac from going to sleep while Glass runs (caffeinate)"
        menu.addItem(macAwakeItem)

        let displayAwakeItem = NSMenuItem(
            title: "Keep Display Awake",
            action: #selector(toggleKeepDisplayAwake(_:)),
            keyEquivalent: "")
        displayAwakeItem.target = self
        displayAwakeItem.state = keepDisplayAwake.isOn ? .on : .off
        displayAwakeItem.toolTip = "Stops the display from turning off while Glass runs (caffeinate -d)"
        menu.addItem(displayAwakeItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit Glass",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func toggleKeepMacAwake(_ sender: NSMenuItem) {
        keepMacAwake.toggle()
        sender.state = keepMacAwake.isOn ? .on : .off
    }

    @objc private func toggleKeepDisplayAwake(_ sender: NSMenuItem) {
        keepDisplayAwake.toggle()
        sender.state = keepDisplayAwake.isOn ? .on : .off
    }

    /// The model's minute tick uses a suspending clock, so after system
    /// sleep the displayed time could lag up to a minute; refresh on wake.
    private func refreshOnWake() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main
        ) { [model] _ in
            Task { @MainActor in model.refresh() }
        }
    }

    private func isOnAnyScreen(_ frame: NSRect) -> Bool {
        NSScreen.screens.contains { $0.visibleFrame.intersects(frame) }
    }
}
