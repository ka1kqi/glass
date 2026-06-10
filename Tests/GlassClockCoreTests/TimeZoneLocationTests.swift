import Foundation
import Testing
@testable import GlassClockCore

/// A realistic zone.tab excerpt: comments, 6-digit and 4-digit coordinate
/// forms, and a trailing-comment column.
private let sampleZoneTab = """
# tzdb timezone descriptions
#
# country-code	coordinates	TZ	comments
US	+404251-0740023	America/New_York	Eastern (most areas)
JP	+353916+1394441	Asia/Tokyo
DE	+5230+01322	Europe/Berlin	Germany (most areas)
AU	-3352+15113	Australia/Sydney	New South Wales (most areas)
"""

@Test func looksUpSixDigitCoordinates() {
    let coords = TimeZoneLocation.coordinates(
        forIdentifier: "America/New_York", inZoneTab: sampleZoneTab)
    #expect(coords != nil)
    #expect(abs(coords!.latitude - 40.714) < 0.01)
    #expect(abs(coords!.longitude - -74.006) < 0.01)
}

@Test func looksUpFourDigitCoordinates() {
    let coords = TimeZoneLocation.coordinates(
        forIdentifier: "Europe/Berlin", inZoneTab: sampleZoneTab)
    #expect(coords != nil)
    #expect(abs(coords!.latitude - 52.5) < 0.01)
    #expect(abs(coords!.longitude - 13.367) < 0.01)
}

@Test func handlesSouthernHemisphere() {
    let coords = TimeZoneLocation.coordinates(
        forIdentifier: "Australia/Sydney", inZoneTab: sampleZoneTab)
    #expect(coords != nil)
    #expect(coords!.latitude < 0)
    #expect(coords!.longitude > 150)
}

@Test func unknownIdentifierReturnsNil() {
    let coords = TimeZoneLocation.coordinates(
        forIdentifier: "Mars/Olympus_Mons", inZoneTab: sampleZoneTab)
    #expect(coords == nil)
}

@Test func systemLookupAlwaysReturnsSomething() {
    // Whether zone.tab parses or the UTC-offset fallback kicks in, the
    // result must be a plausible coordinate.
    let coords = TimeZoneLocation.coordinates(for: .current)
    #expect(abs(coords.latitude) <= 90)
    #expect(abs(coords.longitude) <= 180)
}
