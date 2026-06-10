import AppKit

/// Self-install support: when Glass is launched from a mounted disk image,
/// copy it to /Applications (unless it's already installed), hand off to
/// the installed copy, and quit. This keeps the DMG from ever producing a
/// second install or a second running clock.
@MainActor
enum Installer {
    private static let installedPath = "/Applications/Glass.app"

    /// Returns true if this process should stop launching because it has
    /// handed off to another copy of the app.
    static func handOffToInstalledCopyIfNeeded() -> Bool {
        guard Bundle.main.bundlePath.hasPrefix("/Volumes/") else {
            return deferToExistingInstance()
        }
        let fm = FileManager.default
        if !fm.fileExists(atPath: installedPath) {
            do {
                try fm.copyItem(atPath: Bundle.main.bundlePath, toPath: installedPath)
            } catch {
                // Install failed (permissions?) — fall back to running
                // straight from the DMG rather than dying silently.
                return deferToExistingInstance()
            }
        }
        // Launch the installed copy, then quit this DMG-hosted one.
        // createsNewApplicationInstance is required: otherwise LaunchServices
        // matches our bundle id, "activates" this very process instead of
        // launching the copy in /Applications, and the handoff goes nowhere.
        // If the installed copy was already running, the extra instance this
        // spawns sees it and quits itself, so one clock always remains.
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: installedPath),
            configuration: config
        ) { _, _ in
            Task { @MainActor in NSApp.terminate(nil) }
        }
        return true
    }

    /// If another copy of Glass is already running (other than one on a
    /// disk image, which will hand off and quit by itself), let it win so
    /// there is never more than one clock on screen.
    private static func deferToExistingInstance() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else {
            return false  // bare dev binary, no bundle — skip the check
        }
        let myPID = ProcessInfo.processInfo.processIdentifier
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != myPID }
            .filter { $0.bundleURL?.path.hasPrefix("/Volumes/") != true }
        guard !others.isEmpty else { return false }
        NSApp.terminate(nil)
        return true
    }
}
