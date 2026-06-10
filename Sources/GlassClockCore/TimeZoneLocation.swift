import Foundation

/// Approximate coordinates for a timezone, looked up in the tz database's
/// zone.tab that ships with macOS. Good enough to drive ambient lighting —
/// an error of a few degrees shifts the palette by minutes.
public enum TimeZoneLocation {
    /// Looks up `timeZone` in the system zone.tab; falls back to a
    /// longitude derived from the UTC offset at a mid-northern latitude.
    public static func coordinates(
        for timeZone: TimeZone = .current
    ) -> (latitude: Double, longitude: Double) {
        let paths = [
            "/var/db/timezone/zoneinfo/zone.tab",  // macOS
            "/usr/share/zoneinfo/zone.tab",        // generic Unix
        ]
        for path in paths {
            guard let table = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
            if let found = coordinates(forIdentifier: timeZone.identifier, inZoneTab: table) {
                return found
            }
        }
        // 15° of longitude per hour of UTC offset; latitude is a guess.
        return (35.0, Double(timeZone.secondsFromGMT()) / 3600 * 15)
    }

    /// Parses zone.tab content: tab-separated lines of
    /// `countryCode  ±DDMM±DDDMM[SS…]  Zone/Name  [comment]`.
    static func coordinates(
        forIdentifier identifier: String, inZoneTab table: String
    ) -> (latitude: Double, longitude: Double)? {
        for line in table.split(separator: "\n") {
            guard !line.hasPrefix("#") else { continue }
            let fields = line.split(separator: "\t")
            guard fields.count >= 3, String(fields[2]) == identifier else { continue }
            return parseISO6709(String(fields[1]))
        }
        return nil
    }

    /// "±DDMM±DDDMM" or "±DDMMSS±DDDMMSS" → decimal degrees.
    static func parseISO6709(_ value: String) -> (latitude: Double, longitude: Double)? {
        // The longitude starts at the second sign character.
        guard let split = value.dropFirst().firstIndex(where: { $0 == "+" || $0 == "-" }),
              let latitude = parseAngle(String(value[..<split]), degreeDigits: 2),
              let longitude = parseAngle(String(value[split...]), degreeDigits: 3)
        else { return nil }
        return (latitude, longitude)
    }

    /// "±DDMM[SS]" (degreeDigits 2) or "±DDDMM[SS]" (degreeDigits 3) → degrees.
    private static func parseAngle(_ value: String, degreeDigits: Int) -> Double? {
        guard let sign = value.first, sign == "+" || sign == "-" else { return nil }
        let digits = value.dropFirst()
        guard digits.allSatisfy(\.isNumber),
              digits.count == degreeDigits + 2 || digits.count == degreeDigits + 4,
              let degrees = Double(digits.prefix(degreeDigits)),
              let minutes = Double(digits.dropFirst(degreeDigits).prefix(2))
        else { return nil }
        let seconds = Double(digits.dropFirst(degreeDigits + 2).prefix(2)) ?? 0
        let magnitude = degrees + minutes / 60 + seconds / 3600
        return sign == "-" ? -magnitude : magnitude
    }
}
