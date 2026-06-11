import AppKit
import Combine
import SwiftUI
import GlassClockCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: ClockPanel!
    private var statusItem: NSStatusItem!
    /// One menu, two doors: the status item and right-click on the clock.
    private var menu: NSMenu!
    private let model = ClockModel()
    private let zoom = ZoomModel()
    private let design = DesignModel()
    private let pacer = AmbientPacer()
    private let lighting = LightingModel()
    private let rim = RimLightModel()
    private var zoomHaptics = ZoomHaptics(scale: 1)
    private let chime = Chime()
    private var zoomObserver: AnyCancellable?
    private let keepMacAwake = SleepPreventer.systemSleep()
    private let keepDisplayAwake = SleepPreventer.displaySleep()
    /// Whether the clock floats above all windows (the classic overlay)
    /// or parks below every window, like a desk accessory.
    private var floatsAboveWindows =
        UserDefaults.standard.object(forKey: "GlassFloatsAboveWindows") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(floatsAboveWindows, forKey: "GlassFloatsAboveWindows")
            applyWindowLevel()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if Installer.handOffToInstalledCopyIfNeeded() { return }
        NSApp.setActivationPolicy(.accessory)
        setUpPanel()
        setUpStatusItem()
        refreshOnWake()
        chime.isPaused = { [weak self] in self?.pacer.audioPaused ?? true }
    }

    private func setUpPanel() {
        panel = ClockPanel(contentRect: NSRect(origin: .zero, size: ClockView.baseSize))
        let hosting = NSHostingView(rootView: ClockView(
            model: model, zoom: zoom, design: design, pacer: pacer,
            lighting: lighting, rim: rim))
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
        panel.onDragEnded = { [weak self] velocity in
            self?.settlePanel(velocity: velocity)
        }
        panel.onDraggingChanged = { [weak self] dragging in
            self?.pacer.setDragging(dragging)
        }
        panel.onContextClick = { [weak self] event in
            guard let self, let menu = self.menu,
                  let view = self.panel.contentView else { return }
            NSMenu.popUpContextMenu(menu, with: event, for: view)
        }
        panel.onEngaged = { [weak self] in
            self?.raiseWhileEngaged()
        }
        // Fires immediately with the persisted scale, which also normalizes
        // whatever size the frame autosave restored.
        zoomHaptics = ZoomHaptics(scale: zoom.scale)
        zoomObserver = zoom.$scale.sink { [weak self] scale in
            self?.resizePanel(for: scale)
            self?.zoomHaptics.register(scale)
        }
        panel.orderFrontRegardless()
        applyWindowLevel()
        pacer.start(window: panel)
        rim.start(window: panel, pacer: pacer, lighting: lighting)
    }

    /// One step below normal: every standard window stacks above it.
    private static let deskAccessoryLevel =
        NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue - 1)

    private var parkMonitor: Any?

    private func applyWindowLevel() {
        if floatsAboveWindows {
            panel.level = .floating
            removeParkMonitor()
        } else {
            // Fresh launches (and the just-unchecked moment) keep the
            // clock visible up top; the first click into any other app
            // parks it below the normal band. The level-based park is
            // what makes "behind" stick — Glass never activates, so at
            // .normal it would strand itself above the active app, and
            // ordering games lose to the canJoinAllSpaces re-assertion
            // on Space switches.
            panel.level = .normal
            installParkMonitor()
        }
    }

    /// One-shot: global monitors only see clicks in OTHER apps, so the
    /// first event means the user went back to their work.
    private func installParkMonitor() {
        guard parkMonitor == nil else { return }
        parkMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.removeParkMonitor()
                if !self.floatsAboveWindows {
                    self.panel.level = Self.deskAccessoryLevel
                }
            }
        }
    }

    private func removeParkMonitor() {
        if let parkMonitor {
            NSEvent.removeMonitor(parkMonitor)
            self.parkMonitor = nil
        }
    }

    /// Grabbing a parked clock brings it (and the app) forward so it can
    /// be dragged over other windows; the park monitor then returns it
    /// behind them on the next click into another app.
    private func raiseWhileEngaged() {
        guard !floatsAboveWindows else { return }
        panel.level = .normal
        panel.orderFrontRegardless()
        NSApp.activate()
        installParkMonitor()
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
        rim.nudge()  // the rim geometry changed under a stationary cursor
    }

    /// Carries a little release velocity (the toss), then snaps to a
    /// nearby screen edge — both with one soft-spring animation.
    private func settlePanel(velocity: CGVector) {
        guard let visible = (panel.screen ?? NSScreen.main)?.visibleFrame else { return }
        var target = panel.frame

        if !pacer.reduceMotion {
            // ~60ms of glide, capped so a flick never launches the panel.
            let glideX = min(max(velocity.dx * 0.06, -40), 40)
            let glideY = min(max(velocity.dy * 0.06, -40), 40)
            if abs(glideX) > 1 || abs(glideY) > 1 {
                target.origin.x += glideX
                target.origin.y += glideY
                // The glide itself never pushes the panel off-screen
                // (deliberate partial-offscreen placement stays untouched
                // because a still release has no glide).
                target.origin.x = min(max(target.origin.x, visible.minX),
                                      visible.maxX - target.width)
                target.origin.y = min(max(target.origin.y, visible.minY),
                                      visible.maxY - target.height)
            }
        }

        if let snapped = SnapBehavior.snappedOrigin(for: target, in: visible) {
            target.origin = snapped
        }
        guard target.origin != panel.frame.origin else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = pacer.reduceMotion ? 0 : 0.35
            // Ease-out with a touch of overshoot — the soft-spring settle.
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.3, 0.64, 1)
            panel.animator().setFrame(target, display: true)
        }
        rim.nudge()  // the panel slid away under a stationary cursor
    }

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "clock", accessibilityDescription: "Glass")
        let menu = NSMenu()

        let designItem = NSMenuItem(title: "Design", action: nil, keyEquivalent: "")
        let designMenu = NSMenu()
        for entry in DesignCatalog.all {
            let item = NSMenuItem(
                title: entry.name,
                action: #selector(selectDesign(_:)),
                keyEquivalent: "")
            item.target = self
            item.representedObject = entry.id
            item.state = design.designID == entry.id ? .on : .off
            designMenu.addItem(item)
        }
        designItem.submenu = designMenu
        menu.addItem(designItem)
        menu.addItem(.separator())

        let floatItem = NSMenuItem(
            title: "Float Above Windows",
            action: #selector(toggleFloat(_:)),
            keyEquivalent: "")
        floatItem.target = self
        floatItem.state = floatsAboveWindows ? .on : .off
        floatItem.toolTip = "Off keeps the clock behind your windows"
        menu.addItem(floatItem)

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

        let lightingItem = NSMenuItem(
            title: "Lighting Effects",
            action: #selector(toggleLighting(_:)),
            keyEquivalent: "")
        lightingItem.target = self
        lightingItem.state = lighting.isOn ? .on : .off
        lightingItem.toolTip = "Cursor-lit rim and the minute sheen"
        menu.addItem(lightingItem)

        let chimeItem = NSMenuItem(
            title: "Hourly Chime",
            action: #selector(toggleChime(_:)),
            keyEquivalent: "")
        chimeItem.target = self
        chimeItem.state = chime.isOn ? .on : .off
        chimeItem.toolTip = "A soft glass ting on the hour"
        menu.addItem(chimeItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit Glass",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"))
        statusItem.menu = menu
        self.menu = menu
    }

    @objc private func selectDesign(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        design.designID = id
        sender.menu?.items.forEach {
            $0.state = ($0.representedObject as? String) == id ? .on : .off
        }
    }

    @objc private func toggleKeepMacAwake(_ sender: NSMenuItem) {
        keepMacAwake.toggle()
        sender.state = keepMacAwake.isOn ? .on : .off
    }

    @objc private func toggleKeepDisplayAwake(_ sender: NSMenuItem) {
        keepDisplayAwake.toggle()
        sender.state = keepDisplayAwake.isOn ? .on : .off
    }

    @objc private func toggleFloat(_ sender: NSMenuItem) {
        floatsAboveWindows.toggle()
        sender.state = floatsAboveWindows ? .on : .off
    }

    @objc private func toggleLighting(_ sender: NSMenuItem) {
        lighting.isOn.toggle()
        sender.state = lighting.isOn ? .on : .off
    }

    @objc private func toggleChime(_ sender: NSMenuItem) {
        chime.isOn.toggle()
        sender.state = chime.isOn ? .on : .off
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
