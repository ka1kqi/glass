import Foundation

/// Sun position from the standard low-precision astronomical algorithm
/// (Meeus / NOAA). Accurate to well under a degree — the consumer is
/// ambient lighting, where even a whole degree is invisible.
public enum SolarPosition {
    /// Solar elevation above the horizon, in degrees, at `date` for the
    /// given location. Negative when the sun is below the horizon.
    public static func elevation(latitude: Double, longitude: Double, date: Date) -> Double {
        // Days since J2000.0 (2000-01-01 12:00 UTC).
        let d = date.timeIntervalSince1970 / 86_400 + 2_440_587.5 - 2_451_545.0

        let meanAnomaly = (357.529 + 0.98560028 * d).wrappedDegrees
        let meanLongitude = (280.459 + 0.98564736 * d).wrappedDegrees
        let eclipticLongitude = (meanLongitude
            + 1.915 * sin(meanAnomaly.radians)
            + 0.020 * sin(2 * meanAnomaly.radians)).wrappedDegrees
        let obliquity = 23.439 - 0.00000036 * d

        let declination = asin(sin(obliquity.radians) * sin(eclipticLongitude.radians))
        let rightAscension = atan2(
            cos(obliquity.radians) * sin(eclipticLongitude.radians),
            cos(eclipticLongitude.radians)).degrees.wrappedDegrees

        // Greenwich mean sidereal time, in hours, then the sun's local
        // hour angle in degrees.
        let gmst = 18.697374558 + 24.06570982441908 * d
        // GMST grows unboundedly; wrappedDegrees normalizes after ×15.
        let localSiderealDegrees = (gmst * 15 + longitude).wrappedDegrees
        let hourAngle = (localSiderealDegrees - rightAscension).wrappedDegrees

        let sinElevation = sin(latitude.radians) * sin(declination)
            + cos(latitude.radians) * cos(declination) * cos(hourAngle.radians)
        return asin(min(max(sinElevation, -1), 1)).degrees
    }
}

private extension Double {
    var radians: Double { self * .pi / 180 }
    var degrees: Double { self * 180 / .pi }
    /// Wraps an angle into [0, 360).
    var wrappedDegrees: Double {
        let wrapped = truncatingRemainder(dividingBy: 360)
        return wrapped < 0 ? wrapped + 360 : wrapped
    }
}
