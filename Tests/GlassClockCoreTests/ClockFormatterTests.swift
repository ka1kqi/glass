import Foundation
import Testing
@testable import GlassClockCore

private func makeDate(hour: Int, minute: Int, second: Int) -> Date {
    var components = DateComponents()
    components.year = 2026
    components.month = 6
    components.day = 10
    components.hour = hour
    components.minute = minute
    components.second = second
    return Calendar.current.date(from: components)!
}

@Test func twelveHourLocaleDropsLeadingZeroAndPeriod() {
    let s = ClockFormatter.timeString(
        for: makeDate(hour: 21, minute: 41, second: 0),
        locale: Locale(identifier: "en_US"))
    #expect(s == "9:41")
}

@Test func twentyFourHourLocaleUsesFullHours() {
    let s = ClockFormatter.timeString(
        for: makeDate(hour: 21, minute: 41, second: 0),
        locale: Locale(identifier: "de_DE"))
    #expect(s == "21:41")
}

@Test func twentyFourHourLocalePadsMorningHours() {
    let s = ClockFormatter.timeString(
        for: makeDate(hour: 9, minute: 5, second: 0),
        locale: Locale(identifier: "de_DE"))
    #expect(s == "09:05")
}

@Test func intervalFromMidMinuteReachesNextBoundary() {
    let i = ClockFormatter.intervalToNextMinute(
        from: makeDate(hour: 9, minute: 41, second: 30))
    #expect(abs(i - 30) < 0.001)
}

@Test func intervalFromExactBoundaryIsFullMinute() {
    let i = ClockFormatter.intervalToNextMinute(
        from: makeDate(hour: 9, minute: 41, second: 0))
    #expect(abs(i - 60) < 0.001)
}
