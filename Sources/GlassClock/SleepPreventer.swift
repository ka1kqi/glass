import Foundation
import IOKit.pwr_mgt

/// Holds a power-management assertion — the same mechanism `caffeinate`
/// uses — with the on/off choice persisted across launches. The assertion
/// lives only while Glass runs, just like a `caffeinate` process.
@MainActor
final class SleepPreventer {
    /// `caffeinate`: stops the Mac from idle-sleeping.
    static func systemSleep() -> SleepPreventer {
        SleepPreventer(
            assertionType: kIOPMAssertionTypePreventUserIdleSystemSleep as String,
            defaultsKey: "GlassKeepMacAwake",
            reason: "Glass: Keep Mac Awake is on")
    }

    /// `caffeinate -d`: stops the display from sleeping.
    static func displaySleep() -> SleepPreventer {
        SleepPreventer(
            assertionType: kIOPMAssertionTypePreventUserIdleDisplaySleep as String,
            defaultsKey: "GlassKeepDisplayAwake",
            reason: "Glass: Keep Display Awake is on")
    }

    private let assertionType: String
    private let defaultsKey: String
    private let reason: String
    private var assertionID = IOPMAssertionID(0)
    private(set) var isOn = false

    private init(assertionType: String, defaultsKey: String, reason: String) {
        self.assertionType = assertionType
        self.defaultsKey = defaultsKey
        self.reason = reason
        if UserDefaults.standard.bool(forKey: defaultsKey) {
            turnOn()
        }
    }

    func toggle() {
        isOn ? turnOff() : turnOn()
    }

    private func turnOn() {
        guard !isOn else { return }
        var id = IOPMAssertionID(0)
        guard IOPMAssertionCreateWithName(
            assertionType as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &id) == kIOReturnSuccess else { return }
        assertionID = id
        isOn = true
        UserDefaults.standard.set(true, forKey: defaultsKey)
    }

    private func turnOff() {
        guard isOn else { return }
        IOPMAssertionRelease(assertionID)
        isOn = false
        UserDefaults.standard.set(false, forKey: defaultsKey)
    }
}
