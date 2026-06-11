# Living Glass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Glass feel alive: a pluggable ambient design system (Still Glass + Solar Aurora), a cursor-lit specular rim, a minute-change glint, and physical behaviors (edge snap, toss inertia, haptic zoom detents, optional hourly chime).

**Architecture:** Pure math (solar position, timezone→coords, palette interpolation, snap targets) lives in `GlassClockCore` with unit tests. The app target adds SwiftUI overlay/ambient views composed into `ClockView`'s layer stack, an `AmbientPacer` that pauses all animation when it shouldn't run, and AppKit behaviors on `ClockPanel`/`AppDelegate`. Spec: `docs/superpowers/specs/2026-06-10-living-glass-design.md`.

**Tech Stack:** Swift 6 / SwiftPM (no Xcode project, no dependencies), SwiftUI `MeshGradient` + `TimelineView` (macOS 15), AppKit (`NSPanel`, `NSHapticFeedbackManager`), AVFoundation (synthesized chime), Swift Testing (`@Test` / `#expect`).

**Conventions:** Every Swift file in this repo starts at the top level with imports (no header comments beyond a doc comment on the main type). Tests are free functions marked `@Test` in `Tests/GlassClockCoreTests/`. Run all tests with `swift test`; build the app with `swift build`. Commit after every green step.

---

### Task 1: Raise the platform floor to macOS 15

`MeshGradient` requires macOS 15; the spec locks one render path, no fallbacks.

**Files:**
- Modify: `Package.swift:6`
- Modify: `make-app.sh:24`

- [ ] **Step 1: Edit Package.swift**

Change line 6 from:

```swift
    platforms: [.macOS(.v13)],
```

to:

```swift
    platforms: [.macOS(.v15)],
```

- [ ] **Step 2: Edit make-app.sh minimum system version**

Change line 24 from:

```xml
    <key>LSMinimumSystemVersion</key><string>13.0</string>
```

to:

```xml
    <key>LSMinimumSystemVersion</key><string>15.0</string>
```

- [ ] **Step 3: Verify build and tests still pass**

Run: `swift test`
Expected: all existing ClockFormatter/ClockModel tests pass, zero failures.

- [ ] **Step 4: Commit**

```bash
git add Package.swift make-app.sh
git commit -m "chore: raise minimum platform to macOS 15 for MeshGradient"
```

---

### Task 2: SolarPosition (core, TDD)

Pure solar-elevation math: (latitude, longitude, date) → degrees above horizon. Standard low-precision astronomical algorithm (Meeus/NOAA), accurate to well under a degree — plenty for ambient lighting.

**Files:**
- Create: `Sources/GlassClockCore/SolarPosition.swift`
- Test: `Tests/GlassClockCoreTests/SolarPositionTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/GlassClockCoreTests/SolarPositionTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter SolarPosition`
Expected: compile error — `cannot find 'SolarPosition' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Sources/GlassClockCore/SolarPosition.swift`:

```swift
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter SolarPosition`
Expected: `5 tests passed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/GlassClockCore/SolarPosition.swift Tests/GlassClockCoreTests/SolarPositionTests.swift
git commit -m "feat: add SolarPosition elevation math to core"
```

---

### Task 3: TimeZoneLocation (core, TDD)

Approximate (latitude, longitude) from the system timezone — by parsing the tz database's `zone.tab` shipped with macOS. No network, no permissions. Fallback: longitude from the UTC offset at a mid-northern latitude (crude but harmless; the spec allows palette error of an hour or two).

**Files:**
- Create: `Sources/GlassClockCore/TimeZoneLocation.swift`
- Test: `Tests/GlassClockCoreTests/TimeZoneLocationTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/GlassClockCoreTests/TimeZoneLocationTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter TimeZoneLocation`
Expected: compile error — `cannot find 'TimeZoneLocation' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Sources/GlassClockCore/TimeZoneLocation.swift`:

```swift
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter TimeZoneLocation`
Expected: `5 tests passed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/GlassClockCore/TimeZoneLocation.swift Tests/GlassClockCoreTests/TimeZoneLocationTests.swift
git commit -m "feat: approximate coordinates from timezone via zone.tab"
```

---

### Task 4: AuroraColor + AuroraPalette (core, TDD)

Solar elevation → 9 colors (row-major 3×3) for the mesh, interpolating between keyframe palettes anchored to elevation bands per the spec: night ≤ −12°, dawn at −4°, golden hour at +3°, day at ≥ +25°.

**Files:**
- Create: `Sources/GlassClockCore/AuroraPalette.swift`
- Test: `Tests/GlassClockCoreTests/AuroraPaletteTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/GlassClockCoreTests/AuroraPaletteTests.swift`:

```swift
import Foundation
import Testing
@testable import GlassClockCore

@Test func hexInitializerSplitsChannels() {
    let color = AuroraColor(hex: 0xFF8040)
    #expect(abs(color.red - 1.0) < 0.005)
    #expect(abs(color.green - 0x80 / 255.0) < 0.005)
    #expect(abs(color.blue - 0x40 / 255.0) < 0.005)
}

@Test func lerpMixesChannelsLinearly() {
    let black = AuroraColor(hex: 0x000000)
    let white = AuroraColor(hex: 0xFFFFFF)
    let mid = AuroraColor.lerp(black, white, 0.5)
    #expect(abs(mid.red - 0.5) < 0.005)
    #expect(abs(mid.green - 0.5) < 0.005)
    #expect(abs(mid.blue - 0.5) < 0.005)
}

@Test func paletteAlwaysHasNineColors() {
    for elevation in stride(from: -90.0, through: 90.0, by: 7.5) {
        #expect(AuroraPalette.colors(forElevation: elevation).count == 9)
    }
}

@Test func deepNightClampsToNightAnchor() {
    #expect(AuroraPalette.colors(forElevation: -60) == AuroraPalette.colors(forElevation: -12))
}

@Test func highNoonClampsToDayAnchor() {
    #expect(AuroraPalette.colors(forElevation: 70) == AuroraPalette.colors(forElevation: 25))
}

@Test func anchorElevationsReturnAnchorPalettes() {
    // The −4° anchor is the dawn palette; spot-check its first color.
    let dawn = AuroraPalette.colors(forElevation: -4)
    #expect(dawn[0] == AuroraColor(hex: 0x29005E))
}

@Test func midpointsInterpolateBetweenAdjacentAnchors() {
    // −0.5° is halfway between the −4° (dawn) and +3° (golden) anchors.
    let dawn = AuroraPalette.colors(forElevation: -4)
    let golden = AuroraPalette.colors(forElevation: 3)
    let mid = AuroraPalette.colors(forElevation: -0.5)
    for i in 0..<9 {
        let expected = AuroraColor.lerp(dawn[i], golden[i], 0.5)
        #expect(abs(mid[i].red - expected.red) < 0.001)
        #expect(abs(mid[i].green - expected.green) < 0.001)
        #expect(abs(mid[i].blue - expected.blue) < 0.001)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter AuroraPalette`
Expected: compile error — `cannot find 'AuroraColor' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Sources/GlassClockCore/AuroraPalette.swift`:

```swift
import Foundation

/// An sRGB color value kept in core (no SwiftUI) so palette math stays
/// unit-testable; the app maps these onto SwiftUI colors.
public struct AuroraColor: Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// 0xRRGGBB.
    public init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255)
    }

    public static func lerp(_ a: AuroraColor, _ b: AuroraColor, _ t: Double) -> AuroraColor {
        AuroraColor(
            red: a.red + (b.red - a.red) * t,
            green: a.green + (b.green - a.green) * t,
            blue: a.blue + (b.blue - a.blue) * t)
    }
}

/// Maps solar elevation to a 3×3 mesh palette, interpolating between
/// keyframes so the tint slides continuously through the day — never a
/// binary day/night flip.
public enum AuroraPalette {
    public static let meshWidth = 3
    public static let meshHeight = 3

    /// Keyframe palettes by the solar elevation (degrees) that anchors
    /// them, ascending. Row-major 3×3, top row first.
    static let anchors: [(elevation: Double, colors: [AuroraColor])] = [
        (-12, night), (-4, dawn), (3, golden), (25, day),
    ]

    /// Near-black indigo with faint violet.
    static let night = palette(
        0x0B0B26, 0x141433, 0x1B1040,
        0x10102E, 0x221546, 0x2A1B52,
        0x0B0B22, 0x191038, 0x0E0E26)

    /// Indigo → mauve → dusty rose.
    static let dawn = palette(
        0x29005E, 0x4F1B74, 0x9B6FA7,
        0x3A1466, 0x7A4E96, 0xCCB7C0,
        0x4F1B74, 0x9B6FA7, 0xD9A8B0)

    /// Coral → ember → honey amber.
    static let golden = palette(
        0xCF473B, 0xE5793F, 0xFCA34F,
        0xE5793F, 0xFDCF5A, 0xF1B457,
        0xFCA34F, 0xFDCF5A, 0xFCE49B)

    /// Cool, nearly neutral blue-white.
    static let day = palette(
        0xAFC8D8, 0xC2D4DF, 0xD7E3EA,
        0xB5D6E0, 0xC7E1E5, 0xDDE9EE,
        0xC2D4DF, 0xD7E3EA, 0xE8F0F4)

    /// 9 colors for the given elevation; clamps outside the anchor range.
    public static func colors(forElevation elevation: Double) -> [AuroraColor] {
        guard elevation > anchors.first!.elevation else { return anchors.first!.colors }
        guard elevation < anchors.last!.elevation else { return anchors.last!.colors }
        for i in 0..<(anchors.count - 1) {
            let low = anchors[i], high = anchors[i + 1]
            guard elevation <= high.elevation else { continue }
            let t = (elevation - low.elevation) / (high.elevation - low.elevation)
            return zip(low.colors, high.colors).map { AuroraColor.lerp($0, $1, t) }
        }
        return anchors.last!.colors
    }

    private static func palette(_ hex: UInt32...) -> [AuroraColor] {
        hex.map(AuroraColor.init(hex:))
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter AuroraPalette`
Expected: `7 tests passed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/GlassClockCore/AuroraPalette.swift Tests/GlassClockCoreTests/AuroraPaletteTests.swift
git commit -m "feat: add elevation-keyed aurora palette interpolation"
```

---

### Task 5: SnapBehavior (core, TDD)

Pure math: given the panel frame and a screen's `visibleFrame`, where (if anywhere) should it settle? Per-axis snapping means corners snap on both axes.

**Files:**
- Create: `Sources/GlassClockCore/SnapBehavior.swift`
- Test: `Tests/GlassClockCoreTests/SnapBehaviorTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/GlassClockCoreTests/SnapBehaviorTests.swift`:

```swift
import Foundation
import Testing
@testable import GlassClockCore

// visibleFrame origins are rarely (0,0) in real life (Dock, second
// displays), so test with a shifted screen.
private let screen = CGRect(x: 100, y: 50, width: 1440, height: 800)
private let panelSize = CGSize(width: 340, height: 150)

private func panel(x: CGFloat, y: CGFloat) -> CGRect {
    CGRect(origin: CGPoint(x: x, y: y), size: panelSize)
}

@Test func nearLeftEdgeSnapsXOnly() {
    let snapped = SnapBehavior.snappedOrigin(for: panel(x: 110, y: 400), in: screen)
    #expect(snapped == CGPoint(x: 100, y: 400))
}

@Test func nearRightEdgeSnapsFlush() {
    // Right edge of screen is at 1540; panel maxX 1530 is 10 away.
    let snapped = SnapBehavior.snappedOrigin(for: panel(x: 1190, y: 400), in: screen)
    #expect(snapped == CGPoint(x: 1540 - 340, y: 400))
}

@Test func nearBottomLeftCornerSnapsBothAxes() {
    let snapped = SnapBehavior.snappedOrigin(for: panel(x: 115, y: 60), in: screen)
    #expect(snapped == CGPoint(x: 100, y: 50))
}

@Test func nearTopEdgeSnapsYFlush() {
    // Top of screen is at 850; panel maxY at 840 is 10 away.
    let snapped = SnapBehavior.snappedOrigin(for: panel(x: 700, y: 690), in: screen)
    #expect(snapped == CGPoint(x: 700, y: 850 - 150))
}

@Test func centeredPanelDoesNotSnap() {
    #expect(SnapBehavior.snappedOrigin(for: panel(x: 650, y: 375), in: screen) == nil)
}

@Test func exactlyAtThresholdStillSnaps() {
    let snapped = SnapBehavior.snappedOrigin(for: panel(x: 124, y: 400), in: screen)
    #expect(snapped == CGPoint(x: 100, y: 400))
}

@Test func justBeyondThresholdDoesNotSnap() {
    #expect(SnapBehavior.snappedOrigin(for: panel(x: 125, y: 400), in: screen) == nil)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter SnapBehavior`
Expected: compile error — `cannot find 'SnapBehavior' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Sources/GlassClockCore/SnapBehavior.swift`:

```swift
import Foundation

/// Pure math for settling the panel onto nearby screen edges.
public enum SnapBehavior {
    public static let threshold: CGFloat = 24

    /// If `frame` sits within `threshold` of an edge of `visibleFrame`
    /// (checked per axis, so corners snap on both), returns the origin
    /// that puts it flush against those edges; nil when nothing is close.
    public static func snappedOrigin(
        for frame: CGRect,
        in visibleFrame: CGRect,
        threshold: CGFloat = SnapBehavior.threshold
    ) -> CGPoint? {
        var origin = frame.origin
        var snapped = false
        if abs(frame.minX - visibleFrame.minX) <= threshold {
            origin.x = visibleFrame.minX
            snapped = true
        } else if abs(frame.maxX - visibleFrame.maxX) <= threshold {
            origin.x = visibleFrame.maxX - frame.width
            snapped = true
        }
        if abs(frame.minY - visibleFrame.minY) <= threshold {
            origin.y = visibleFrame.minY
            snapped = true
        } else if abs(frame.maxY - visibleFrame.maxY) <= threshold {
            origin.y = visibleFrame.maxY - frame.height
            snapped = true
        }
        return snapped ? origin : nil
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter SnapBehavior`
Expected: `7 tests passed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/GlassClockCore/SnapBehavior.swift Tests/GlassClockCoreTests/SnapBehaviorTests.swift
git commit -m "feat: add edge-snap target math to core"
```

---

### Task 6: AmbientPacer (app)

Single source of truth for "should ambient animation run?" Pauses on occlusion, screen/system sleep, Low Power Mode, and Reduce Motion; also exposes `reduceMotion` on its own because it additionally disables the glint and toss.

**Files:**
- Create: `Sources/GlassClock/AmbientPacer.swift`

- [ ] **Step 1: Write the implementation**

Create `Sources/GlassClock/AmbientPacer.swift`:

```swift
import AppKit
import Combine

/// Single source of truth for whether ambient animation should run.
/// Everything animated takes `paused` as its TimelineView pause flag, so
/// the whole app goes quiet from one place.
@MainActor
final class AmbientPacer: ObservableObject {
    @Published private(set) var paused = false
    /// Reduce Motion also pauses, but glint/toss need it separately.
    @Published private(set) var reduceMotion = false

    private weak var window: NSWindow?
    private var screenAsleep = false

    /// Begins observing; call once after the panel exists.
    func start(window: NSWindow) {
        self.window = window
        let center = NotificationCenter.default
        let workspace = NSWorkspace.shared.notificationCenter

        center.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: window, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.refresh() } }

        // Both screen sleep and full system sleep stop the show; either
        // wake notification restarts it.
        let sleepers: [(Notification.Name, Bool)] = [
            (NSWorkspace.screensDidSleepNotification, true),
            (NSWorkspace.screensDidWakeNotification, false),
            (NSWorkspace.willSleepNotification, true),
            (NSWorkspace.didWakeNotification, false),
        ]
        for (name, asleep) in sleepers {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.screenAsleep = asleep
                    self?.refresh()
                }
            }
        }

        center.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.refresh() } }

        workspace.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.refresh() } }

        refresh()
    }

    private func refresh() {
        reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let occluded = !(window?.occlusionState.contains(.visible) ?? true)
        paused = screenAsleep
            || occluded
            || ProcessInfo.processInfo.isLowPowerModeEnabled
            || reduceMotion
    }
}
```

- [ ] **Step 2: Verify it builds**

Run: `swift build`
Expected: `Build complete!` (the type is not referenced yet — that's fine).

- [ ] **Step 3: Commit**

```bash
git add Sources/GlassClock/AmbientPacer.swift
git commit -m "feat: add AmbientPacer pausing ambient work when it shouldn't run"
```

---

### Task 7: Design system — GlassDesign, DesignCatalog, DesignModel (app)

The pluggable design registry. Ships here with only Still Glass (today's look — an empty ambient layer); Solar Aurora joins the catalog in Task 8. Selection persists under the `GlassDesign` defaults key, falling back to the first catalog entry for unknown ids.

**Files:**
- Create: `Sources/GlassClock/GlassDesign.swift`
- Create: `Sources/GlassClock/DesignModel.swift`

- [ ] **Step 1: Write GlassDesign + DesignCatalog**

Create `Sources/GlassClock/GlassDesign.swift`:

```swift
import SwiftUI

/// One ambient look for the glass. A design contributes the layer
/// rendered between the blur material and the clock digits; the rim and
/// glint overlays are shared by all designs.
@MainActor
protocol GlassDesign {
    /// Stable identifier persisted in UserDefaults — never change one.
    var id: String { get }
    /// Menu title.
    var name: String { get }
    /// The ambient layer; built fresh whenever the design is applied.
    func ambientLayer(paused: Bool) -> AnyView
}

/// Today's look, exactly: no ambient layer at all.
struct StillGlassDesign: GlassDesign {
    let id = "still-glass"
    let name = "Still Glass"
    func ambientLayer(paused: Bool) -> AnyView { AnyView(EmptyView()) }
}

/// Every available design, in menu order. The first entry is the default
/// and the fallback for unknown persisted ids.
@MainActor
enum DesignCatalog {
    static let all: [any GlassDesign] = [
        StillGlassDesign(),
    ]

    static func design(withID id: String) -> any GlassDesign {
        all.first { $0.id == id } ?? all[0]
    }
}
```

- [ ] **Step 2: Write DesignModel**

Create `Sources/GlassClock/DesignModel.swift`:

```swift
import Foundation
import Combine

/// The selected glass design, persisted across launches.
@MainActor
final class DesignModel: ObservableObject {
    private static let defaultsKey = "GlassDesign"

    @Published var designID: String {
        didSet { UserDefaults.standard.set(designID, forKey: Self.defaultsKey) }
    }

    var current: any GlassDesign { DesignCatalog.design(withID: designID) }

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.defaultsKey) ?? ""
        // Round-trip through the catalog normalizes unknown ids.
        designID = DesignCatalog.design(withID: saved).id
    }
}
```

- [ ] **Step 3: Verify it builds**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 4: Commit**

```bash
git add Sources/GlassClock/GlassDesign.swift Sources/GlassClock/DesignModel.swift
git commit -m "feat: add pluggable glass design system with persisted selection"
```

---

### Task 8: GrainOverlay + SolarAuroraLayer + SolarAuroraDesign (app)

The flagship design: a 15fps `MeshGradient` whose 3×3 points drift on slow mutually-prime periods (so the field never visibly repeats) and whose colors follow real solar elevation, finished with static film grain baked once per launch.

**Files:**
- Create: `Sources/GlassClock/GrainOverlay.swift`
- Create: `Sources/GlassClock/SolarAuroraLayer.swift`
- Modify: `Sources/GlassClock/GlassDesign.swift` (add `SolarAuroraDesign`, register in catalog)

- [ ] **Step 1: Write GrainOverlay**

Create `Sources/GlassClock/GrainOverlay.swift`:

```swift
import SwiftUI
import AppKit

/// Static film grain that keeps low-opacity gradients from banding.
/// Generated once per launch (never animated — animated noise is the
/// expensive kind) and tiled across the panel.
enum Grain {
    static let image: NSImage = {
        let size = 128
        var bytes = [UInt8](repeating: 0, count: size * size)
        for i in bytes.indices { bytes[i] = UInt8.random(in: 0...255) }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        let cgImage = CGImage(
            width: size, height: size,
            bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: size,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false,
            intent: .defaultIntent)!
        return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
    }()
}

struct GrainOverlay: View {
    var body: some View {
        Image(nsImage: Grain.image)
            .resizable(resizingMode: .tile)
            .opacity(0.04)
            .blendMode(.overlay)
            .allowsHitTesting(false)
    }
}
```

- [ ] **Step 2: Write SolarAuroraLayer**

Create `Sources/GlassClock/SolarAuroraLayer.swift`:

```swift
import SwiftUI
import GlassClockCore

/// The flagship ambient layer: a slowly drifting mesh gradient whose
/// palette follows the real sun's elevation at the timezone-approximated
/// location. 15 fps is the ceiling — the motion is glacial by design.
struct SolarAuroraLayer: View {
    var paused: Bool

    /// Resolved once per launch; a stale location only shifts the palette
    /// by minutes, invisible at this opacity.
    private static let location = TimeZoneLocation.coordinates()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: paused)) { context in
            let elevation = SolarPosition.elevation(
                latitude: Self.location.latitude,
                longitude: Self.location.longitude,
                date: context.date)
            MeshGradient(
                width: AuroraPalette.meshWidth,
                height: AuroraPalette.meshHeight,
                points: Self.points(at: context.date.timeIntervalSinceReferenceDate),
                colors: AuroraPalette.colors(forElevation: elevation).map {
                    Color(red: $0.red, green: $0.green, blue: $0.blue)
                })
        }
        .opacity(0.2)
        .allowsHitTesting(false)
    }

    /// Corners stay pinned and edge midpoints drift only along their own
    /// edge (MeshGradient requires boundary points on the boundary); the
    /// periods are mutually prime so the field never visibly repeats.
    static func points(at t: TimeInterval) -> [SIMD2<Float>] {
        func drift(
            _ base: SIMD2<Float>,
            dx: Float, dy: Float,
            px: Double, py: Double
        ) -> SIMD2<Float> {
            SIMD2(
                base.x + dx * Float(sin(t * 2 * .pi / px)),
                base.y + dy * Float(cos(t * 2 * .pi / py)))
        }
        return [
            SIMD2(0, 0),
            drift(SIMD2(0.5, 0), dx: 0.18, dy: 0, px: 23, py: 1),
            SIMD2(1, 0),
            drift(SIMD2(0, 0.5), dx: 0, dy: 0.16, px: 1, py: 29),
            drift(SIMD2(0.5, 0.5), dx: 0.22, dy: 0.20, px: 37, py: 41),
            drift(SIMD2(1, 0.5), dx: 0, dy: 0.16, px: 1, py: 31),
            SIMD2(0, 1),
            drift(SIMD2(0.5, 1), dx: 0.18, dy: 0, px: 43, py: 1),
            SIMD2(1, 1),
        ]
    }
}
```

- [ ] **Step 3: Add SolarAuroraDesign and register it**

In `Sources/GlassClock/GlassDesign.swift`, add after `StillGlassDesign`:

```swift
/// Living glass: time-of-day aurora plus film grain.
struct SolarAuroraDesign: GlassDesign {
    let id = "solar-aurora"
    let name = "Solar Aurora"
    func ambientLayer(paused: Bool) -> AnyView {
        AnyView(SolarAuroraLayer(paused: paused).overlay(GrainOverlay()))
    }
}
```

and change the catalog list to:

```swift
    static let all: [any GlassDesign] = [
        StillGlassDesign(),
        SolarAuroraDesign(),
    ]
```

- [ ] **Step 4: Verify it builds**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 5: Commit**

```bash
git add Sources/GlassClock/GrainOverlay.swift Sources/GlassClock/SolarAuroraLayer.swift Sources/GlassClock/GlassDesign.swift
git commit -m "feat: add Solar Aurora design — solar-tinted drifting mesh with grain"
```

---

### Task 9: SpecularRimOverlay (app)

A 1pt hairline rim on all designs, plus a soft arc of light on the side of the panel facing the mouse cursor — anywhere on the desktop — fading with distance. Polls `NSEvent.mouseLocation` on the shared 15fps timeline; no event monitors, no permissions.

**Files:**
- Create: `Sources/GlassClock/SpecularRimOverlay.swift`

- [ ] **Step 1: Write the implementation**

Create `Sources/GlassClock/SpecularRimOverlay.swift`:

```swift
import SwiftUI
import AppKit

/// The panel's hairline rim plus a soft specular arc on the side facing
/// the mouse cursor, as if the cursor were a light source the glass
/// catches. Full strength within ~150pt of the rim, gone beyond ~600pt.
struct SpecularRimOverlay: View {
    var paused: Bool
    var cornerRadius: CGFloat
    /// Panel frame in screen coordinates (y up), polled per frame.
    var windowFrame: () -> NSRect?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: paused)) { _ in
            let light = Self.light(panel: windowFrame(), mouse: NSEvent.mouseLocation)
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            shape
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                .overlay {
                    if light.intensity > 0 {
                        shape.strokeBorder(
                            AngularGradient(
                                stops: [
                                    .init(color: .white.opacity(0.55 * light.intensity), location: 0),
                                    .init(color: .clear, location: 0.18),
                                    .init(color: .clear, location: 0.82),
                                    .init(color: .white.opacity(0.55 * light.intensity), location: 1),
                                ],
                                center: .center,
                                angle: .radians(light.angle)),
                            lineWidth: 1)
                    }
                }
        }
        .allowsHitTesting(false)
    }

    /// Angle (SwiftUI radians, y down) toward the cursor and a 0–1
    /// intensity from its distance to the rim.
    static func light(panel: NSRect?, mouse: NSPoint) -> (angle: Double, intensity: Double) {
        guard let panel else { return (0, 0) }
        let dx = mouse.x - panel.midX
        let dy = mouse.y - panel.midY
        let centerDistance = (dx * dx + dy * dy).squareRoot()
        let halfDiagonal = (panel.width * panel.width + panel.height * panel.height).squareRoot() / 2
        let rimDistance = max(0, centerDistance - halfDiagonal)
        let intensity = max(0, 1 - max(0, rimDistance - 150) / 450)
        // Screen coordinates are y-up; SwiftUI angles are y-down.
        return (atan2(-dy, dx), Double(intensity))
    }
}
```

- [ ] **Step 2: Verify it builds**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/GlassClock/SpecularRimOverlay.swift
git commit -m "feat: add cursor-lit specular rim overlay"
```

---

### Task 10: MinuteGlintOverlay (app)

A one-shot ~650ms diagonal light sweep, fired whenever the displayed time string changes. Never loops; disabled under Reduce Motion.

**Files:**
- Create: `Sources/GlassClock/MinuteGlintOverlay.swift`

- [ ] **Step 1: Write the implementation**

Create `Sources/GlassClock/MinuteGlintOverlay.swift`:

```swift
import SwiftUI

/// A one-shot diagonal light sweep across the glass, fired each time the
/// displayed time changes — a visual tick. Never loops.
struct MinuteGlintOverlay: View {
    /// The time string; any change fires one sweep.
    var trigger: String
    /// False under Reduce Motion.
    var enabled: Bool
    var cornerRadius: CGFloat

    /// 0 = sweep parked off the leading edge, 2 = parked off the trailing
    /// edge (the resting state).
    @State private var phase: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            let travel = geo.size.width + geo.size.height
            Rectangle()
                .fill(LinearGradient(
                    colors: [.clear, .white.opacity(0.08), .clear],
                    startPoint: .leading, endPoint: .trailing))
                .frame(width: geo.size.width * 0.45, height: travel * 2)
                .rotationEffect(.degrees(45))
                .blur(radius: 6)
                .position(x: phase * travel - travel / 2, y: geo.size.height / 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .allowsHitTesting(false)
        .onChange(of: trigger) {
            guard enabled else { return }
            // Jump to the start without animating, then sweep across.
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) { phase = 0 }
            withAnimation(.easeInOut(duration: 0.65)) { phase = 2 }
        }
    }
}
```

- [ ] **Step 2: Verify it builds**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/GlassClock/MinuteGlintOverlay.swift
git commit -m "feat: add one-shot minute glint sweep"
```

---

### Task 11: Assemble the layer stack + Design menu (app, integration)

Wire everything: `ClockView` gains the ambient/rim/glint layers with a cross-fade on design switch; `AppDelegate` creates `DesignModel` + `AmbientPacer`, passes the panel-frame closure, and adds the Design submenu.

**Files:**
- Modify: `Sources/GlassClock/ClockView.swift` (full rewrite below)
- Modify: `Sources/GlassClock/AppDelegate.swift` (properties, `setUpPanel`, `setUpStatusItem`)

- [ ] **Step 1: Rewrite ClockView**

Replace the whole body of `Sources/GlassClock/ClockView.swift` with:

```swift
import SwiftUI
import GlassClockCore

struct ClockView: View {
    /// Size of the panel at 1x zoom; everything scales from here.
    static let baseSize = NSSize(width: 340, height: 150)

    @ObservedObject var model: ClockModel
    @ObservedObject var zoom: ZoomModel
    @ObservedObject var design: DesignModel
    @ObservedObject var pacer: AmbientPacer
    /// Panel frame in screen coordinates, for the cursor-lit rim.
    var windowFrame: () -> NSRect? = { nil }

    var body: some View {
        let radius = 24 * zoom.scale
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        Text(model.timeString)
            .font(.system(size: 88 * zoom.scale, weight: .medium, design: .rounded))
            .foregroundStyle(.primary)
            .frame(width: Self.baseSize.width * zoom.scale,
                   height: Self.baseSize.height * zoom.scale)
            .background {
                ZStack {
                    VisualEffectBackground(cornerRadius: radius)
                    design.current.ambientLayer(paused: pacer.paused)
                        .clipShape(shape)
                        .id(design.designID)        // new identity per design…
                        .transition(.opacity)        // …so switching cross-fades
                }
                .animation(.easeInOut(duration: 0.4), value: design.designID)
            }
            .overlay {
                MinuteGlintOverlay(
                    trigger: model.timeString,
                    enabled: !pacer.reduceMotion,
                    cornerRadius: radius)
            }
            .overlay {
                SpecularRimOverlay(
                    paused: pacer.paused,
                    cornerRadius: radius,
                    windowFrame: windowFrame)
            }
    }
}
```

- [ ] **Step 2: Wire AppDelegate**

In `Sources/GlassClock/AppDelegate.swift`:

(a) Add two stored properties after `private let zoom = ZoomModel()` (line 11):

```swift
    private let design = DesignModel()
    private let pacer = AmbientPacer()
```

(b) In `setUpPanel()`, replace the hosting-view line

```swift
        let hosting = NSHostingView(rootView: ClockView(model: model, zoom: zoom))
```

with:

```swift
        let hosting = NSHostingView(rootView: ClockView(
            model: model, zoom: zoom, design: design, pacer: pacer,
            windowFrame: { [weak panel] in panel?.frame }))
```

(Note: `panel` is assigned on the line above, so the capture is valid.)

(c) At the end of `setUpPanel()`, after `panel.orderFrontRegardless()`, add:

```swift
        pacer.start(window: panel)
```

(d) In `setUpStatusItem()`, right after `let menu = NSMenu()`, add the Design submenu:

```swift
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
```

(e) Add the action method next to the other `@objc` methods:

```swift
    @objc private func selectDesign(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        design.designID = id
        sender.menu?.items.forEach {
            $0.state = ($0.representedObject as? String) == id ? .on : .off
        }
    }
```

- [ ] **Step 3: Build and run the test suite**

Run: `swift test`
Expected: all tests pass — the original suite plus the 24 core tests added in Tasks 2–5.

- [ ] **Step 4: Manual verification**

Run: `./make-app.sh && open build/Glass.app`

Checklist:
- Menu bar clock icon → **Design** submenu shows "Still Glass" (checked) and "Solar Aurora".
- Selecting **Solar Aurora** cross-fades in a soft tinted gradient behind the digits; it drifts very slowly. Selecting Still Glass fades it out.
- A faint 1pt rim is visible; moving the cursor near the panel brightens the rim on the side facing the cursor; far away it returns to plain.
- When the minute changes, a subtle diagonal sheen sweeps across once.
- Quit and relaunch: the selected design is remembered.

- [ ] **Step 5: Commit**

```bash
git add Sources/GlassClock/ClockView.swift Sources/GlassClock/AppDelegate.swift
git commit -m "feat: assemble living-glass layer stack and Design menu"
```

---

### Task 12: Manual drag with toss inertia + edge snap (app)

Replace `isMovableByWindowBackground` with a manual drag (mouseDown/Dragged/Up on the panel) so we can measure release velocity. On release: a short capped glide from the velocity, then `SnapBehavior` settles the panel onto a nearby edge with a soft-spring curve. Reduce Motion skips the glide and animates snapping with zero duration. Frame autosave keeps working — programmatic moves still fire `windowDidMove`.

**Files:**
- Modify: `Sources/GlassClock/ClockPanel.swift`
- Modify: `Sources/GlassClock/AppDelegate.swift` (settle handler)

- [ ] **Step 1: Add manual drag to ClockPanel**

In `Sources/GlassClock/ClockPanel.swift`:

(a) In `init`, change line 17 from:

```swift
        isMovableByWindowBackground = true
```

to:

```swift
        // Dragging is manual (mouseDown/Dragged/Up below) so release
        // velocity can drive the toss glide.
        isMovableByWindowBackground = false
```

(b) After the `onZoom` property (line 27), add:

```swift
    /// Called when a drag ends, with the release velocity in points/sec
    /// (screen coordinates, y up).
    var onDragEnded: ((CGVector) -> Void)?

    /// Pointer offset from the frame origin while dragging, screen coords.
    private var dragOffset: NSPoint?
    /// Recent (timestamp, origin) samples for the release velocity.
    private var dragSamples: [(time: TimeInterval, origin: NSPoint)] = []

    override func mouseDown(with event: NSEvent) {
        let mouse = NSEvent.mouseLocation
        dragOffset = NSPoint(x: mouse.x - frame.origin.x, y: mouse.y - frame.origin.y)
        dragSamples = [(event.timestamp, frame.origin)]
    }

    override func mouseDragged(with event: NSEvent) {
        guard let offset = dragOffset else { return }
        let mouse = NSEvent.mouseLocation
        setFrameOrigin(NSPoint(x: mouse.x - offset.x, y: mouse.y - offset.y))
        dragSamples.append((event.timestamp, frame.origin))
        if dragSamples.count > 8 { dragSamples.removeFirst(dragSamples.count - 8) }
    }

    override func mouseUp(with event: NSEvent) {
        guard dragOffset != nil else { return }
        dragOffset = nil
        let velocity = Self.releaseVelocity(from: dragSamples)
        dragSamples = []
        onDragEnded?(velocity)
    }

    /// Velocity over the last ~120ms of samples, so pausing mid-drag
    /// before releasing kills the toss.
    static func releaseVelocity(from samples: [(time: TimeInterval, origin: NSPoint)]) -> CGVector {
        guard let last = samples.last else { return .zero }
        let recent = samples.filter { $0.time >= last.time - 0.12 }
        guard let first = recent.first, last.time > first.time else { return .zero }
        let dt = last.time - first.time
        return CGVector(
            dx: (last.origin.x - first.origin.x) / dt,
            dy: (last.origin.y - first.origin.y) / dt)
    }
```

- [ ] **Step 2: Add the settle handler in AppDelegate**

In `Sources/GlassClock/AppDelegate.swift`:

(a) Add `import GlassClockCore` if not already present (it is — line 4). In `setUpPanel()`, after the `panel.onZoom = ...` line, add:

```swift
        panel.onDragEnded = { [weak self] velocity in
            self?.settlePanel(velocity: velocity)
        }
```

(b) Add the method after `resizePanel(for:)`:

```swift
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
    }
```

- [ ] **Step 3: Build and test**

Run: `swift test`
Expected: all tests pass.

- [ ] **Step 4: Manual verification**

Run: `./make-app.sh && open build/Glass.app`

Checklist:
- Dragging the panel works exactly as before (grab anywhere, smooth).
- Releasing a moving drag glides the panel a few points further with an eased stop.
- Releasing within ~24pt of a screen edge settles the panel flush against it, corners settle on both axes.
- A drag released in the middle of the screen, motionless, does not move.
- Position persists across relaunch (autosave unaffected).
- Pinch/scroll zoom still works.

- [ ] **Step 5: Commit**

```bash
git add Sources/GlassClock/ClockPanel.swift Sources/GlassClock/AppDelegate.swift
git commit -m "feat: manual drag with toss inertia and soft edge snapping"
```

---

### Task 13: Haptic zoom detents (app)

A trackpad tick (`NSHapticFeedbackManager`) when the zoom scale crosses 1.0× and when it first hits either limit (0.5× / 2.5×).

**Files:**
- Create: `Sources/GlassClock/ZoomHaptics.swift`
- Modify: `Sources/GlassClock/AppDelegate.swift` (zoom observer)

- [ ] **Step 1: Write ZoomHaptics**

Create `Sources/GlassClock/ZoomHaptics.swift`:

```swift
import AppKit

/// Trackpad ticks at meaningful zoom moments: crossing the natural 1.0×
/// size, and hitting either end of the zoom range.
@MainActor
struct ZoomHaptics {
    private var lastScale: CGFloat

    init(scale: CGFloat) {
        lastScale = scale
    }

    mutating func register(_ scale: CGFloat) {
        defer { lastScale = scale }
        guard scale != lastScale else { return }
        let crossedNatural = (lastScale - 1).sign != (scale - 1).sign
        let hitLimit = scale == ZoomModel.range.lowerBound
            || scale == ZoomModel.range.upperBound
        guard crossedNatural || hitLimit else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment, performanceTime: .now)
    }
}
```

- [ ] **Step 2: Hook into the zoom observer**

In `Sources/GlassClock/AppDelegate.swift`:

(a) Add a property after `private let pacer = AmbientPacer()`:

```swift
    private var zoomHaptics = ZoomHaptics(scale: 1)
```

(b) In `setUpPanel()`, replace the zoom observer:

```swift
        zoomObserver = zoom.$scale.sink { [weak self] scale in
            self?.resizePanel(for: scale)
        }
```

with:

```swift
        zoomHaptics = ZoomHaptics(scale: zoom.scale)
        zoomObserver = zoom.$scale.sink { [weak self] scale in
            self?.resizePanel(for: scale)
            self?.zoomHaptics.register(scale)
        }
```

(Seeding with the restored scale means the initial sink fire is a no-op
— no tick on launch.)

- [ ] **Step 3: Build and verify manually**

Run: `swift test` (expect all pass), then `./make-app.sh && open build/Glass.app`.

Checklist (needs a Force Touch trackpad):
- Slowly scroll-zoom through 1.0×: one tick as it crosses.
- Zoom to either end of the range: one tick on arrival, none while pinned there.

- [ ] **Step 4: Commit**

```bash
git add Sources/GlassClock/ZoomHaptics.swift Sources/GlassClock/AppDelegate.swift
git commit -m "feat: haptic detents at natural size and zoom limits"
```

---

### Task 14: Hourly chime (app)

A soft glass "ting" on the hour — decaying inharmonic sine partials synthesized with AVAudioEngine (no bundled asset). Off by default, toggled from the menu, persisted, and silent while the pacer is paused.

**Files:**
- Create: `Sources/GlassClock/Chime.swift`
- Modify: `Sources/GlassClock/AppDelegate.swift` (property, pause hookup, menu item)

- [ ] **Step 1: Write Chime**

Create `Sources/GlassClock/Chime.swift`:

```swift
import AVFoundation
import Foundation

/// A soft synthesized glass "ting" on the hour. Off by default; persisted.
@MainActor
final class Chime {
    private static let defaultsKey = "HourlyChime"

    var isOn: Bool {
        didSet {
            UserDefaults.standard.set(isOn, forKey: Self.defaultsKey)
            isOn ? scheduleNextHour() : cancel()
        }
    }

    /// Skips the ting while ambient work is paused (asleep, hidden,
    /// Low Power Mode…). Wired to AmbientPacer by the app delegate.
    var isPaused: () -> Bool = { false }

    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var timer: Timer?

    init() {
        isOn = UserDefaults.standard.bool(forKey: Self.defaultsKey)
        if isOn { scheduleNextHour() }
    }

    private func scheduleNextHour() {
        cancel()
        let next = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(minute: 0, second: 0),
            matchingPolicy: .nextTime) ?? Date().addingTimeInterval(3600)
        let timer = Timer(fire: next, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isOn else { return }
                if !self.isPaused() { self.play() }
                self.scheduleNextHour()
            }
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func cancel() {
        timer?.invalidate()
        timer = nil
    }

    private func play() {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        // A failed engine just means no decoration this hour.
        guard let buffer = Self.tingBuffer(format: format),
              (try? engine.start()) != nil else { return }
        self.engine = engine
        self.player = player
        player.scheduleBuffer(buffer) { [weak self] in
            Task { @MainActor in
                self?.engine?.stop()
                self?.engine = nil
                self?.player = nil
            }
        }
        player.play()
    }

    /// Decaying inharmonic sine partials — the sound of a tapped
    /// wineglass. Glass partials are not harmonic; the ~2.76× and ~5.1×
    /// ratios are what make it read as glass rather than a bell.
    private static func tingBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let frames = AVAudioFrameCount(sampleRate * 1.8)
        guard sampleRate > 0, format.channelCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)
        else { return nil }
        buffer.frameLength = frames
        let partials: [(frequency: Double, amplitude: Double, decay: Double)] = [
            (1318.5, 0.20, 3.0),
            (3638.0, 0.10, 5.5),
            (6724.0, 0.05, 8.0),
        ]
        for frame in 0..<Int(frames) {
            let t = Double(frame) / sampleRate
            var sample = 0.0
            for p in partials {
                sample += p.amplitude * sin(2 * .pi * p.frequency * t) * exp(-p.decay * t)
            }
            sample *= min(1, t / 0.005)  // 5ms attack so it doesn't click
            for channel in 0..<Int(format.channelCount) {
                buffer.floatChannelData?[channel][frame] = Float(sample)
            }
        }
        return buffer
    }
}
```

- [ ] **Step 2: Wire into AppDelegate**

In `Sources/GlassClock/AppDelegate.swift`:

(a) Add a property after `private var zoomHaptics = ZoomHaptics(scale: 1)`:

```swift
    private let chime = Chime()
```

(b) In `applicationDidFinishLaunching`, after `refreshOnWake()`, add:

```swift
        chime.isPaused = { [weak self] in self?.pacer.paused ?? true }
```

(c) In `setUpStatusItem()`, after the `displayAwakeItem` block and before
`menu.addItem(.separator())`, add:

```swift
        let chimeItem = NSMenuItem(
            title: "Hourly Chime",
            action: #selector(toggleChime(_:)),
            keyEquivalent: "")
        chimeItem.target = self
        chimeItem.state = chime.isOn ? .on : .off
        chimeItem.toolTip = "A soft glass ting on the hour"
        menu.addItem(chimeItem)
```

(d) Add the action next to the other toggles:

```swift
    @objc private func toggleChime(_ sender: NSMenuItem) {
        chime.isOn.toggle()
        sender.state = chime.isOn ? .on : .off
    }
```

- [ ] **Step 3: Build and verify manually**

Run: `swift test` (expect all pass), then `./make-app.sh && open build/Glass.app`.

Checklist:
- Menu shows "Hourly Chime", unchecked by default.
- To hear it without waiting for the hour: temporarily change
  `DateComponents(minute: 0, second: 0)` to a minute one ahead of now,
  rebuild, enable the toggle, and wait — a soft glass ting plays. Revert
  the change afterward (verify with `git diff` that Chime.swift is clean).
- Toggle state survives relaunch.

- [ ] **Step 4: Commit**

```bash
git add Sources/GlassClock/Chime.swift Sources/GlassClock/AppDelegate.swift
git commit -m "feat: optional synthesized hourly glass chime"
```

---

### Task 15: README, version bump, final verification

**Files:**
- Modify: `README.md` (feature list)
- Modify: `make-app.sh:22-23` (version 1.1.0 → 1.2.0, bundle version 2 → 3)

- [ ] **Step 1: Update README feature list**

In `README.md`, replace the bullet list under "Build & run" (lines 28–34) with:

```markdown
- Drag the clock anywhere; its position is remembered. Tossing it glides
  with a little inertia, and it settles flush onto nearby screen edges.
- Pinch or scroll on the clock to make it bigger or smaller (0.5x–2.5x);
  it zooms around its center with a haptic tick at natural size, and the
  size is remembered too.
- Pick a look under the menu bar clock icon → Design: **Still Glass**
  (classic frost) or **Solar Aurora** — a slow ambient gradient behind the
  glass, tinted by the real position of the sun at your location (computed
  offline from your timezone; no location permission). The glass edge
  catches light from your cursor, and a subtle sheen sweeps across each
  minute change.
- The same menu has settings: Keep Mac Awake (`caffeinate`), Keep Display
  Awake (`caffeinate -d`), and an off-by-default Hourly Chime (a soft
  synthesized glass ting) — all remembered across launches.
- Ambient effects pause automatically when the clock is hidden, the screen
  sleeps, Low Power Mode is on, or Reduce Motion is set.
- Follows your system 12/24-hour setting; adapts to light/dark mode.
  Requires macOS 15.
```

- [ ] **Step 2: Bump versions in make-app.sh**

Change lines 22–23 from:

```xml
    <key>CFBundleShortVersionString</key><string>1.1.0</string>
    <key>CFBundleVersion</key><string>2</string>
```

to:

```xml
    <key>CFBundleShortVersionString</key><string>1.2.0</string>
    <key>CFBundleVersion</key><string>3</string>
```

- [ ] **Step 3: Full verification**

Run: `swift test`
Expected: all tests pass.

Run: `./make-app.sh && open build/Glass.app`
Full manual sweep: design switching + persistence, rim light, minute glint, drag/toss/snap, zoom haptics, chime toggle, Keep Awake toggles still work, quit/relaunch restores everything.

Optional energy spot-check (spec): with Solar Aurora active, run
`sudo powermetrics --samplers gpu_power -n 5 -i 1000` and confirm GPU
power is within a few percent of the Still Glass baseline.

- [ ] **Step 4: Commit**

```bash
git add README.md make-app.sh
git commit -m "chore: document living glass and bump version to 1.2.0"
```

---

## Spec coverage map

| Spec requirement | Task |
|---|---|
| macOS 15 floor | 1 |
| GlassDesign protocol / catalog / persisted selection / Design submenu | 7, 11 |
| Still Glass + Solar Aurora designs | 7, 8 |
| Solar elevation math, timezone location, palette keyframes (tested) | 2, 3, 4 |
| MeshGradient aurora @15fps + grain | 8 |
| Specular rim (all designs) | 9, 11 |
| Minute glint (all designs) | 10, 11 |
| AmbientPacer energy rules | 6, 11 |
| Edge/corner snap (tested math) + toss inertia | 5, 12 |
| Haptic zoom detents | 13 |
| Hourly chime (off by default, synthesized, pause-aware) | 14 |
| README/docs/version | 15 |
