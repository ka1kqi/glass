import Foundation
import Testing
@testable import GlassClockCore

/// Builds a UTC date; all reference values below are in UTC.
private func utc(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar.date(from: DateComponents(
        year: year, month: month, day: day, hour: hour, minute: minute))!
}

@Test func summerSolsticeNoonAtGreenwich() {
    // 90° − latitude + declination ≈ 90 − 51.48 + 23.44 ≈ 61.9°.
    let e = SolarPosition.elevation(
        latitude: 51.4779, longitude: 0, date: utc(2026, 6, 21, 12, 0))
    #expect(abs(e - 61.9) < 1.5)
}

@Test func summerSolsticeMidnightAtGreenwichIsBelowHorizon() {
    // Lower culmination: declination − (90 − latitude) ≈ −15°.
    let e = SolarPosition.elevation(
        latitude: 51.4779, longitude: 0, date: utc(2026, 6, 21, 0, 0))
    #expect(e < -10)
}

@Test func equinoxSolarNoonAtEquatorIsNearZenith() {
    // Solar noon at longitude 0 on 2026-03-20 is ~12:07 UTC (equation of time).
    let e = SolarPosition.elevation(
        latitude: 0, longitude: 0, date: utc(2026, 3, 20, 12, 7))
    #expect(e > 85)
}

@Test func polarNightStaysDark() {
    // Longyearbyen in early January: the sun never rises.
    let e = SolarPosition.elevation(
        latitude: 78.22, longitude: 15.65, date: utc(2026, 1, 5, 12, 0))
    #expect(e < -5)
}

@Test func easternLongitudeShiftsSolarNoonEarlier() {
    // When it's noon in Greenwich, Tokyo (lon ~139.7°E) is in the evening.
    let greenwich = SolarPosition.elevation(
        latitude: 35.65, longitude: 0, date: utc(2026, 6, 21, 12, 0))
    let tokyo = SolarPosition.elevation(
        latitude: 35.65, longitude: 139.7, date: utc(2026, 6, 21, 12, 0))
    #expect(tokyo < greenwich)
}
