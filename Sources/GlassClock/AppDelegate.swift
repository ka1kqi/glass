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

    func applicationDidFinishLaunching(_ notification: Notification) {
        if Installer.handOffToInstalledCopyIfNeeded() { return }
        NSApp.setActivationPolicy(.accessory)
        setUpPanel()
        setUpStatusItem()
        refreshOnWake()
    }

    private func setUpPanel() {
        panel = ClockPanel(contentRect: NSRect(origin: .zero, size: ClockView.baseSize))
        panel.contentView = NSHostingView(rootView: ClockView(model: model, zoom: zoom))
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
        menu.addItem(NSMenuItem(
            title: "Quit Glass",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"))
        statusItem.menu = menu
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
