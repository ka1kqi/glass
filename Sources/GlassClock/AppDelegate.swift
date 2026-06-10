import AppKit
import SwiftUI
import GlassClockCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: ClockPanel!
    private var statusItem: NSStatusItem!
    private let model = ClockModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setUpPanel()
        setUpStatusItem()
        refreshOnWake()
    }

    private func setUpPanel() {
        let size = NSSize(width: 340, height: 150)
        panel = ClockPanel(contentRect: NSRect(origin: .zero, size: size))
        panel.contentView = NSHostingView(rootView: ClockView(model: model))
        panel.setFrameAutosaveName("GlassClockPanel")
        if !isOnAnyScreen(panel.frame) {
            panel.center()
        }
        panel.orderFrontRegardless()
    }

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "clock", accessibilityDescription: "GlassClock")
        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: "Quit GlassClock",
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
