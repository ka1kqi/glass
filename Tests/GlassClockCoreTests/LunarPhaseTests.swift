import Foundation
import Testing
@testable import GlassClockCore

private func utc(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar.date(from: DateComponents(
        year: year, month: month, day: day, hour: hour, minute: minute))!
}

@Test func epochIsANewMoon() {
    #expect(LunarPhase.phase(at: utc(2000, 1, 6, 18, 14)) < 0.01)
    #expect(LunarPhase.illumination(at: utc(2000, 1, 6, 18, 14)) < 0.01)
}

@Test func knownFullMoonIsNearHalfPhase() {
    // 2000-01-21 04:44 UTC — the total lunar eclipse, necessarily full.
    let phase = LunarPhase.phase(at: utc(2000, 1, 21, 4, 44))
    #expect(abs(phase - 0.5) < 0.03)
    #expect(LunarPhase.illumination(at: utc(2000, 1, 21, 4, 44)) > 0.97)
}

@Test func nextNewMoonWrapsToZero() {
    // 2000-02-05 13:03 UTC.
    let phase = LunarPhase.phase(at: utc(2000, 2, 5, 13, 3))
    #expect(phase < 0.03 || phase > 0.97)
}

@Test func phaseIsPeriodic() {
    let a = LunarPhase.phase(at: utc(2026, 6, 10, 12, 0))
    let b = LunarPhase.phase(
        at: utc(2026, 6, 10, 12, 0).addingTimeInterval(29.53058867 * 86_400))
    #expect(abs(a - b) < 0.001)
}

@Test func preEpochDatesWrapPositive() {
    let phase = LunarPhase.phase(at: utc(1999, 12, 1, 0, 0))
    #expect(phase >= 0 && phase < 1)
}

@Test func lunarRimAccentBrightensWithIllumination() {
    let new = LunarPalette.rimAccent(illumination: 0)
    let full = LunarPalette.rimAccent(illumination: 1)
    #expect(new == AuroraColor.lerp(
        AuroraColor(hex: 0x9FB6D9), AuroraColor(red: 1, green: 1, blue: 1), 0.35))
    #expect(full == AuroraColor.lerp(
        AuroraColor(hex: 0x9FB6D9), AuroraColor(red: 1, green: 1, blue: 1), 0.70))
    #expect(full.red > new.red)
}

@Test func lunarRimAccentClampsIllumination() {
    #expect(LunarPalette.rimAccent(illumination: -1)
        == LunarPalette.rimAccent(illumination: 0))
    #expect(LunarPalette.rimAccent(illumination: 2)
        == LunarPalette.rimAccent(illumination: 1))
}
