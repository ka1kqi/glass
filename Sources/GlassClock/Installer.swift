import AppKit
import GlassClockCore

/// Self-install support: when Glass is launched from a mounted disk image,
/// copy it to /Applications (installing fresh, or replacing an older
/// version), hand off to the installed copy, and quit. This keeps the DMG
/// from ever producing a second install or a second running clock.
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
        } else if installedCopyIsOlder() {
            // Upgrade: quit the outdated copy and replace it. On failure,
            // run from the DMG rather than handing off to stale code.
            guard replaceInstalledCopy() else { return deferToExistingInstance() }
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

    /// True when the copy in /Applications reports an older
    /// CFBundleShortVersionString than this bundle. Unreadable versions
    /// count as not-older, so a broken read never clobbers an install.
    private static func installedCopyIsOlder() -> Bool {
        guard let mine = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let theirs = Bundle(path: installedPath)?
                  .infoDictionary?["CFBundleShortVersionString"] as? String
        else { return false }
        return BundleVersion.isVersion(theirs, olderThan: mine)
    }

    /// Quits any running non-DMG copies (they're about to be stale), then
    /// swaps the installed bundle for this one. Termination is a polite
    /// request, but Glass quits instantly — it holds no unsaved state.
    private static func replaceInstalledCopy() -> Bool {
        let stale = otherNonDMGInstances()
        stale.forEach { $0.terminate() }
        // Wait for them to exit (briefly) so the handed-off copy doesn't
        // see a dying instance and defer to it. Poll the pids directly:
        // NSRunningApplication.isTerminated only refreshes while the main
        // run loop spins, which it doesn't during this blocking wait.
        let pids = stale.map(\.processIdentifier)
        let deadline = Date().addingTimeInterval(2)
        while pids.contains(where: { kill($0, 0) == 0 }), Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        // Copy beside the install first, then swap atomically, so a
        // failure (disk full, permissions) never leaves /Applications
        // without a working copy.
        let fm = FileManager.default
        let staging = URL(fileURLWithPath: "/Applications/.Glass.upgrade.app")
        do {
            try? fm.removeItem(at: staging)
            try fm.copyItem(at: URL(fileURLWithPath: Bundle.main.bundlePath), to: staging)
            _ = try fm.replaceItemAt(URL(fileURLWithPath: installedPath), withItemAt: staging)
            return true
        } catch {
            try? fm.removeItem(at: staging)
            return false
        }
    }

    /// Running copies of Glass other than this process and any DMG-hosted
    /// ones (those hand off and quit by themselves).
    private static func otherNonDMGInstances() -> [NSRunningApplication] {
        guard let bundleID = Bundle.main.bundleIdentifier else { return [] }
        let myPID = ProcessInfo.processInfo.processIdentifier
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != myPID }
            .filter { $0.bundleURL?.path.hasPrefix("/Volumes/") != true }
    }

    /// If another copy of Glass is already running (other than one on a
    /// disk image, which will hand off and quit by itself), let it win so
    /// there is never more than one clock on screen.
    private static func deferToExistingInstance() -> Bool {
        guard Bundle.main.bundleIdentifier != nil else {
            return false  // bare dev binary, no bundle — skip the check
        }
        guard !otherNonDMGInstances().isEmpty else { return false }
        NSApp.terminate(nil)
        return true
    }
}
