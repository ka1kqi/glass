# Caustics, Lunar Tide, Releases & Core Hardening — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Two new render-server-animated designs (Caustics, Lunar Tide), CI + tag-driven DMG releases, and core-tested extraction of the remaining pure math (drag velocity, rim light, zoom detents).

**Architecture:** All new math lives TDD'd in `GlassClockCore`. Designs follow the `AuroraDriftView` pattern: pre-rendered textures on `CALayer`s, repeating render-server transform animations, one commit per minute, shared `LayerClock` pause idiom. Spec: `docs/superpowers/specs/2026-06-10-caustics-lunar-releases-design.md`.

**Tech Stack:** Swift 6 / SwiftPM, CoreAnimation, Swift Testing, GitHub Actions (macos-15 runner).

**Conventions:** Tests are `@Test` free functions in `Tests/GlassClockCoreTests/`. `swift test` / `swift build`. Commit per task with the trailer `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`. Baseline: 42 tests passing.

---

### Task 1: LunarPhase + LunarPalette (core, TDD)

**Files:**
- Create: `Sources/GlassClockCore/LunarPhase.swift`
- Test: `Tests/GlassClockCoreTests/LunarPhaseTests.swift`

- [ ] **Step 1: Failing tests** — create `Tests/GlassClockCoreTests/LunarPhaseTests.swift`:

```swift
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
```

- [ ] **Step 2:** `swift test --filter LunarPhase` — expect compile error (`cannot find 'LunarPhase'`).

- [ ] **Step 3: Implement** — create `Sources/GlassClockCore/LunarPhase.swift`:

```swift
import Foundation

/// Mean-synodic lunar phase — accurate to roughly half a day, plenty for
/// an ambient glow.
public enum LunarPhase {
    /// Days in a mean synodic month.
    static let synodicMonth = 29.53058867
    /// The new moon of 2000-01-06 18:14 UTC, in seconds since 1970.
    static let epoch: TimeInterval = 947_182_440

    /// Phase fraction in [0, 1): 0 = new, 0.5 = full.
    public static func phase(at date: Date) -> Double {
        let days = (date.timeIntervalSince1970 - epoch) / 86_400
        let wrapped = (days / synodicMonth).truncatingRemainder(dividingBy: 1)
        return wrapped < 0 ? wrapped + 1 : wrapped
    }

    /// Illuminated fraction 0…1: 0 at new, 1 at full.
    public static func illumination(at date: Date) -> Double {
        (1 - cos(2 * .pi * phase(at: date))) / 2
    }
}

/// Colors for the Lunar Tide design: a constant night field (it does not
/// follow the sun — that's its identity) and a moonlight rim accent.
public enum LunarPalette {
    /// Top → bottom stops of the indigo night field.
    public static let field = [
        AuroraColor(hex: 0x0A0E1E),
        AuroraColor(hex: 0x101A33),
        AuroraColor(hex: 0x070B16),
    ]

    /// Silver-blue moonlight; a fuller moon lifts it further toward white.
    public static func rimAccent(illumination: Double) -> AuroraColor {
        let clamped = min(max(illumination, 0), 1)
        return AuroraColor.lerp(
            AuroraColor(hex: 0x9FB6D9),
            AuroraColor(red: 1, green: 1, blue: 1),
            0.35 + 0.35 * clamped)
    }
}
```

- [ ] **Step 4:** `swift test --filter Lunar` — 7 tests pass. Full `swift test` — 49 pass.

- [ ] **Step 5: Commit** — `git add Sources/GlassClockCore/LunarPhase.swift Tests/GlassClockCoreTests/LunarPhaseTests.swift && git commit -m "feat: lunar phase math and moonlight palette in core"`

---

### Task 2: CausticsTile (core, TDD)

**Files:**
- Create: `Sources/GlassClockCore/CausticsTile.swift`
- Test: `Tests/GlassClockCoreTests/CausticsTileTests.swift`

- [ ] **Step 1: Failing tests** — create `Tests/GlassClockCoreTests/CausticsTileTests.swift`:

```swift
import Foundation
import Testing
@testable import GlassClockCore

@Test func toroidalDistanceWrapsTheShortWay() {
    let d = CausticsTile.toroidalDistance(SIMD2(0.05, 0.5), SIMD2(0.95, 0.5))
    #expect(abs(d - 0.1) < 0.0001)
    let symmetric = CausticsTile.toroidalDistance(SIMD2(0.95, 0.5), SIMD2(0.05, 0.5))
    #expect(abs(d - symmetric) < 0.0001)
}

@Test func tileIsDeterministicPerSeed() {
    #expect(CausticsTile.luminance(size: 64, seed: 9)
        == CausticsTile.luminance(size: 64, seed: 9))
    #expect(CausticsTile.luminance(size: 64, seed: 9)
        != CausticsTile.luminance(size: 64, seed: 23))
}

@Test func tileUsesTheFullLuminanceRange() {
    let bytes = CausticsTile.luminance(size: 128)
    #expect(bytes.count == 128 * 128)
    #expect(bytes.max()! >= 200)   // bright web lines
    #expect(bytes.min()! <= 30)    // dark cell interiors
}

@Test func tileWrapsSeamlessly() {
    // The jump across the wrapped edge should look like any interior
    // jump — statistically, not exactly (adjacent columns differ too).
    let size = 128
    let bytes = CausticsTile.luminance(size: size)
    func meanColumnDiff(_ a: Int, _ b: Int) -> Double {
        var total = 0.0
        for y in 0..<size {
            total += abs(Double(bytes[y * size + a]) - Double(bytes[y * size + b]))
        }
        return total / Double(size)
    }
    let wrapJump = meanColumnDiff(0, size - 1)
    var interior = 0.0
    for x in 0..<(size - 1) { interior += meanColumnDiff(x, x + 1) }
    interior /= Double(size - 1)
    #expect(wrapJump <= interior * 2 + 1)
}
```

- [ ] **Step 2:** `swift test --filter CausticsTile` — compile error expected.

- [ ] **Step 3: Implement** — create `Sources/GlassClockCore/CausticsTile.swift`:

```swift
import Foundation

/// A deterministic, seamlessly tileable grayscale caustics field: bright
/// Voronoi cell edges, like sunlight webbing on a pool floor. The app
/// rasterizes this once and lets the render server drift it.
public enum CausticsTile {
    /// size×size luminance bytes, row-major.
    public static func luminance(
        size: Int,
        featureCount: Int = 14,
        lineScale: Double = 6.5,
        sharpness: Double = 2.4,
        seed: UInt64 = 9
    ) -> [UInt8] {
        var rng = SplitMix64(seed: seed)
        let features = (0..<featureCount).map { _ in
            SIMD2(rng.unitDouble(), rng.unitDouble())
        }
        var bytes = [UInt8](repeating: 0, count: size * size)
        for y in 0..<size {
            for x in 0..<size {
                let point = SIMD2(Double(x) / Double(size), Double(y) / Double(size))
                var nearest = Double.infinity
                var second = Double.infinity
                for feature in features {
                    let distance = toroidalDistance(point, feature)
                    if distance < nearest {
                        second = nearest
                        nearest = distance
                    } else if distance < second {
                        second = distance
                    }
                }
                // Cell edges have F2 ≈ F1; that's where the light webs.
                let edge = max(0, 1 - (second - nearest) * lineScale)
                bytes[y * size + x] = UInt8(min(255, pow(edge, sharpness) * 255))
            }
        }
        return bytes
    }

    /// Distance on the unit torus, so the field tiles seamlessly.
    static func toroidalDistance(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        var dx = abs(a.x - b.x); dx = min(dx, 1 - dx)
        var dy = abs(a.y - b.y); dy = min(dy, 1 - dy)
        return (dx * dx + dy * dy).squareRoot()
    }
}

/// Tiny deterministic RNG so tiles are reproducible (and testable).
struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func unitDouble() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
}
```

- [ ] **Step 4:** `swift test --filter CausticsTile` — 4 pass. Full suite — 53. If the range or wrap assertions fail, report the actual values rather than tuning constants blind.

- [ ] **Step 5: Commit** — `git commit -m "feat: tileable Voronoi caustics field in core"`

---

### Task 3: PaletteMath + CausticsPalette (core, TDD)

`AuroraPalette.colors(forElevation:)` and the new water palette share the anchor-interpolation scheme — extract it once.

**Files:**
- Create: `Sources/GlassClockCore/CausticsPalette.swift`
- Modify: `Sources/GlassClockCore/AuroraPalette.swift` (delegate to shared interpolation)
- Test: `Tests/GlassClockCoreTests/CausticsPaletteTests.swift`

- [ ] **Step 1: Failing tests** — create `Tests/GlassClockCoreTests/CausticsPaletteTests.swift`:

```swift
import Foundation
import Testing
@testable import GlassClockCore

@Test func waterPaletteHasThreeStops() {
    for elevation in stride(from: -90.0, through: 90.0, by: 10.0) {
        #expect(CausticsPalette.colors(forElevation: elevation).count == 3)
    }
}

@Test func waterPaletteClampsAndHitsAnchors() {
    #expect(CausticsPalette.colors(forElevation: -60)
        == CausticsPalette.colors(forElevation: -12))
    #expect(CausticsPalette.colors(forElevation: 70)
        == CausticsPalette.colors(forElevation: 25))
    #expect(CausticsPalette.colors(forElevation: 25)[0] == AuroraColor(hex: 0x57B8CE))
}

@Test func waterMidpointsInterpolate() {
    let dusk = CausticsPalette.colors(forElevation: -4)
    let golden = CausticsPalette.colors(forElevation: 3)
    let mid = CausticsPalette.colors(forElevation: -0.5)
    for i in 0..<3 {
        let expected = AuroraColor.lerp(dusk[i], golden[i], 0.5)
        #expect(abs(mid[i].red - expected.red) < 0.001)
        #expect(abs(mid[i].green - expected.green) < 0.001)
        #expect(abs(mid[i].blue - expected.blue) < 0.001)
    }
}

@Test func waterRimAccentReadsAsLight() {
    for elevation in stride(from: -90.0, through: 90.0, by: 15.0) {
        let accent = CausticsPalette.rimAccent(forElevation: elevation)
        #expect(accent.red >= 0.6 && accent.green >= 0.6 && accent.blue >= 0.6)
    }
}

@Test func auroraPaletteUnchangedByRefactor() {
    // Pin a couple of pre-refactor values so the extraction is provably
    // behavior-preserving.
    #expect(AuroraPalette.colors(forElevation: -4)[0] == AuroraColor(hex: 0x29005E))
    let dawn = AuroraPalette.colors(forElevation: -4)
    let golden = AuroraPalette.colors(forElevation: 3)
    let mid = AuroraPalette.colors(forElevation: -0.5)
    #expect(abs(mid[0].red - AuroraColor.lerp(dawn[0], golden[0], 0.5).red) < 0.001)
}
```

- [ ] **Step 2:** `swift test --filter CausticsPalette` — compile error expected.

- [ ] **Step 3: Implement** — create `Sources/GlassClockCore/CausticsPalette.swift`:

```swift
import Foundation

/// Shared anchor-interpolation for elevation-keyed palettes.
enum PaletteMath {
    /// Linear interpolation between adjacent anchor palettes, clamped
    /// outside the anchor range. Anchors must be sorted ascending.
    static func interpolate(
        anchors: [(elevation: Double, colors: [AuroraColor])],
        elevation: Double
    ) -> [AuroraColor] {
        guard elevation > anchors.first!.elevation else { return anchors.first!.colors }
        guard elevation < anchors.last!.elevation else { return anchors.last!.colors }
        for i in 0..<(anchors.count - 1) {
            let low = anchors[i], high = anchors[i + 1]
            guard elevation <= high.elevation else { continue }
            let t = (elevation - low.elevation) / (high.elevation - low.elevation)
            return zip(low.colors, high.colors).map { AuroraColor.lerp($0, $1, t) }
        }
        // Unreachable: the guards bound elevation strictly inside the range.
        return anchors.last!.colors
    }
}

/// Water colors for the Caustics design: a 3-stop vertical gradient
/// (top → bottom) keyed to solar elevation, same anchors as the aurora.
public enum CausticsPalette {
    static let anchors: [(elevation: Double, colors: [AuroraColor])] = [
        (-12, night), (-4, dusk), (3, golden), (25, day),
    ]

    /// Deep navy night water.
    static let night = stops(0x06121F, 0x0A1C2E, 0x040B14)
    /// Teal dusk.
    static let dusk = stops(0x123246, 0x1A4A5E, 0x0A2433)
    /// Warm shallows at golden hour.
    static let golden = stops(0x2E6E7A, 0x3E8E96, 0x16414E)
    /// Bright midday aqua.
    static let day = stops(0x57B8CE, 0x7FD2E0, 0x2E7E96)

    /// Gradient stops for the given elevation, clamped outside anchors.
    public static func colors(forElevation elevation: Double) -> [AuroraColor] {
        PaletteMath.interpolate(anchors: anchors, elevation: elevation)
    }

    /// Rim arc accent: the mid water color lifted 60% toward white.
    public static func rimAccent(forElevation elevation: Double) -> AuroraColor {
        AuroraColor.lerp(
            colors(forElevation: elevation)[1],
            AuroraColor(red: 1, green: 1, blue: 1),
            0.6)
    }

    private static func stops(_ hex: UInt32...) -> [AuroraColor] {
        hex.map(AuroraColor.init(hex:))
    }
}
```

and in `Sources/GlassClockCore/AuroraPalette.swift` replace the body of `colors(forElevation:)` with:

```swift
    /// 9 colors for the given elevation; clamps outside the anchor range.
    public static func colors(forElevation elevation: Double) -> [AuroraColor] {
        PaletteMath.interpolate(anchors: anchors, elevation: elevation)
    }
```

(delete the now-duplicated loop and the unreachable-return comment from that method only — everything else in the file stays).

- [ ] **Step 4:** Full `swift test` — 58 pass (53 + 5; ALL existing aurora tests must still pass — they prove the refactor preserved behavior).

- [ ] **Step 5: Commit** — `git commit -m "feat: water palette for caustics; share anchor interpolation"`

---

### Task 4: DragMath extraction (core, TDD)

**Files:**
- Create: `Sources/GlassClockCore/DragMath.swift`
- Modify: `Sources/GlassClock/ClockPanel.swift` (delegate; delete local copy)
- Test: `Tests/GlassClockCoreTests/DragMathTests.swift`

- [ ] **Step 1: Failing tests** — create `Tests/GlassClockCoreTests/DragMathTests.swift`:

```swift
import Foundation
import Testing
@testable import GlassClockCore

@Test func steadyDragYieldsItsVelocity() {
    // 100 pt/s rightward, sampled every 20ms.
    let samples = (0...5).map { i in
        (time: Double(i) * 0.02, origin: CGPoint(x: Double(i) * 2, y: 0))
    }
    let v = DragMath.releaseVelocity(samples: samples, releasedAt: 0.1)
    #expect(abs(v.dx - 100) < 0.001)
    #expect(abs(v.dy) < 0.001)
}

@Test func flickThenHoldReleasesAtZero() {
    // Fast movement, then 300ms of stillness before release: every
    // sample is older than the 120ms window.
    let samples = (0...5).map { i in
        (time: Double(i) * 0.02, origin: CGPoint(x: Double(i) * 10, y: 0))
    }
    let v = DragMath.releaseVelocity(samples: samples, releasedAt: 0.1 + 0.3)
    #expect(v == .zero)
}

@Test func singleSampleReleasesAtZero() {
    let v = DragMath.releaseVelocity(
        samples: [(time: 0, origin: CGPoint(x: 5, y: 5))], releasedAt: 0.05)
    #expect(v == .zero)
}

@Test func emptySamplesReleaseAtZero() {
    #expect(DragMath.releaseVelocity(samples: [], releasedAt: 1) == .zero)
}
```

- [ ] **Step 2:** `swift test --filter DragMath` — compile error expected.

- [ ] **Step 3: Implement** — create `Sources/GlassClockCore/DragMath.swift`:

```swift
import Foundation

/// Pure math for the panel's toss gesture.
public enum DragMath {
    /// Velocity over the last `window` seconds before release. Filtering
    /// against the release timestamp (not the last drag sample) means a
    /// flick followed by a motionless hold releases with zero velocity.
    public static func releaseVelocity(
        samples: [(time: TimeInterval, origin: CGPoint)],
        releasedAt upTime: TimeInterval,
        window: TimeInterval = 0.12
    ) -> CGVector {
        let recent = samples.filter { $0.time >= upTime - window }
        guard let first = recent.first, let last = recent.last,
              last.time > first.time else { return .zero }
        let dt = last.time - first.time
        return CGVector(
            dx: (last.origin.x - first.origin.x) / dt,
            dy: (last.origin.y - first.origin.y) / dt)
    }
}
```

Then in `Sources/GlassClock/ClockPanel.swift`: change the `mouseUp` call to `DragMath.releaseVelocity(samples: dragSamples, releasedAt: event.timestamp)` and DELETE the whole local `static func releaseVelocity` (its doc comment moved to core). `ClockPanel` already builds `(time:, origin:)` tuples — `NSPoint` is `CGPoint`, so they pass straight through. Add `import GlassClockCore` if missing (check the file's imports).

- [ ] **Step 4:** Full `swift test` — 62 pass; `swift build` clean.

- [ ] **Step 5: Commit** — `git commit -m "refactor: move toss velocity math to core with tests"`

---

### Task 5: RimLight extraction (core, TDD)

**Files:**
- Create: `Sources/GlassClockCore/RimLight.swift`
- Modify: `Sources/GlassClock/SpecularRimOverlay.swift` (delete static `light`), `Sources/GlassClock/RimLightModel.swift` (call core)
- Test: `Tests/GlassClockCoreTests/RimLightTests.swift`

- [ ] **Step 1: Failing tests** — create `Tests/GlassClockCoreTests/RimLightTests.swift`:

```swift
import Foundation
import Testing
@testable import GlassClockCore

private let panel = CGRect(x: 100, y: 100, width: 340, height: 150)

@Test func cursorAboveLightsTheTop() {
    // Screen coords are y-up; SwiftUI angles y-down, so "above" is −π/2.
    let light = RimLight.compute(panel: panel, mouse: CGPoint(x: panel.midX, y: panel.maxY + 50))
    #expect(abs(light.angle - (-Double.pi / 2)) < 0.001)
    #expect(light.intensity == 1)
}

@Test func cursorRightLightsTheRight() {
    let light = RimLight.compute(panel: panel, mouse: CGPoint(x: panel.maxX + 50, y: panel.midY))
    #expect(abs(light.angle) < 0.001)
    #expect(light.intensity == 1)
}

@Test func cursorBelowAndLeftFlipCorrectly() {
    let below = RimLight.compute(panel: panel, mouse: CGPoint(x: panel.midX, y: panel.minY - 50))
    #expect(abs(below.angle - Double.pi / 2) < 0.001)
    let left = RimLight.compute(panel: panel, mouse: CGPoint(x: panel.minX - 50, y: panel.midY))
    #expect(abs(abs(left.angle) - Double.pi) < 0.001)
}

@Test func intensityFallsOffMonotonicallyToZero() {
    let halfDiagonal = (panel.width * panel.width + panel.height * panel.height)
        .squareRoot() / 2
    func intensity(atRimDistance d: CGFloat) -> Double {
        RimLight.compute(
            panel: panel,
            mouse: CGPoint(x: panel.midX + halfDiagonal + d, y: panel.midY)).intensity
    }
    #expect(intensity(atRimDistance: 100) == 1)          // inside grace zone
    let near = intensity(atRimDistance: 200)
    let far = intensity(atRimDistance: 500)
    #expect(near > far)
    #expect(intensity(atRimDistance: 700) == 0)          // beyond 600
}

@Test func nilPanelIsDark() {
    let light = RimLight.compute(panel: nil, mouse: .zero)
    #expect(light.intensity == 0)
}
```

- [ ] **Step 2:** `swift test --filter RimLight` — compile error expected.

- [ ] **Step 3: Implement** — create `Sources/GlassClockCore/RimLight.swift` (the body is the existing `SpecularRimOverlay.light` verbatim, CG types instead of NS):

```swift
import Foundation

/// Pure math for the cursor-lit rim: which way the light points and how
/// strong it is. Full strength within ~150pt of the rim, gone past 600pt.
public enum RimLight {
    /// Angle (SwiftUI radians, y down) toward the cursor and a 0–1
    /// intensity from its distance to the rim. Inputs in screen
    /// coordinates (y up).
    public static func compute(
        panel: CGRect?, mouse: CGPoint
    ) -> (angle: Double, intensity: Double) {
        guard let panel else { return (0, 0) }
        let dx = mouse.x - panel.midX
        let dy = mouse.y - panel.midY
        let centerDistance = (dx * dx + dy * dy).squareRoot()
        let halfDiagonal = (panel.width * panel.width + panel.height * panel.height)
            .squareRoot() / 2
        let rimDistance = max(0, centerDistance - halfDiagonal)
        let intensity = max(0, 1 - max(0, rimDistance - 150) / 450)
        // Screen coordinates are y-up; SwiftUI angles are y-down.
        return (atan2(-dy, dx), Double(intensity))
    }
}
```

Then: in `Sources/GlassClock/RimLightModel.swift` replace `SpecularRimOverlay.light(panel: frame, mouse: NSEvent.mouseLocation)` with `RimLight.compute(panel: frame, mouse: NSEvent.mouseLocation)` (add `import GlassClockCore`). In `Sources/GlassClock/SpecularRimOverlay.swift` DELETE the static `light` function (nothing else references it — verify with grep before and after).

- [ ] **Step 4:** Full `swift test` — 67 pass; `swift build` clean; `grep -rn "SpecularRimOverlay.light" Sources/` returns nothing.

- [ ] **Step 5: Commit** — `git commit -m "refactor: move rim light math to core with tests"`

---

### Task 6: ZoomDetents extraction (core, TDD)

**Files:**
- Create: `Sources/GlassClockCore/ZoomDetents.swift`
- Modify: `Sources/GlassClock/ZoomHaptics.swift` (delegate)
- Test: `Tests/GlassClockCoreTests/ZoomDetentsTests.swift`

- [ ] **Step 1: Failing tests** — create `Tests/GlassClockCoreTests/ZoomDetentsTests.swift`:

```swift
import Foundation
import Testing
@testable import GlassClockCore

private let range: ClosedRange<CGFloat> = 0.5...2.5

@Test func crossingNaturalSizeTicksBothDirections() {
    #expect(ZoomDetents.shouldTick(from: 0.95, to: 1.05, range: range))
    #expect(ZoomDetents.shouldTick(from: 1.05, to: 0.95, range: range))
}

@Test func landingExactlyOnNaturalTicksBothDirections() {
    #expect(ZoomDetents.shouldTick(from: 1.05, to: 1.0, range: range))
    #expect(ZoomDetents.shouldTick(from: 0.95, to: 1.0, range: range))
}

@Test func leavingNaturalDoesNotTick() {
    #expect(!ZoomDetents.shouldTick(from: 1.0, to: 0.9, range: range))
    #expect(!ZoomDetents.shouldTick(from: 1.0, to: 1.1, range: range))
}

@Test func arrivingAtLimitsTicks() {
    #expect(ZoomDetents.shouldTick(from: 0.6, to: 0.5, range: range))
    #expect(ZoomDetents.shouldTick(from: 2.4, to: 2.5, range: range))
}

@Test func pinnedAtLimitStaysSilent() {
    #expect(!ZoomDetents.shouldTick(from: 0.5, to: 0.5, range: range))
    #expect(!ZoomDetents.shouldTick(from: 2.5, to: 2.5, range: range))
}

@Test func midRangeMovementIsSilent() {
    #expect(!ZoomDetents.shouldTick(from: 1.5, to: 1.6, range: range))
}
```

- [ ] **Step 2:** `swift test --filter ZoomDetents` — compile error expected.

- [ ] **Step 3: Implement** — create `Sources/GlassClockCore/ZoomDetents.swift`:

```swift
import Foundation

/// When a zoom change deserves a haptic tick.
public enum ZoomDetents {
    /// True when moving from `old` to `new` crosses (or lands exactly on)
    /// the natural 1.0× size, or arrives at either end of `range`.
    public static func shouldTick(
        from old: CGFloat, to new: CGFloat, range: ClosedRange<CGFloat>
    ) -> Bool {
        guard new != old else { return false }
        // Explicit comparisons, not .sign: (0).sign is .plus, which would
        // miss a descent landing exactly on 1.0.
        let crossedNatural = (old > 1 && new <= 1) || (old < 1 && new >= 1)
        let hitLimit = new == range.lowerBound || new == range.upperBound
        return crossedNatural || hitLimit
    }
}
```

Then rewrite `Sources/GlassClock/ZoomHaptics.swift`'s `register` to:

```swift
    mutating func register(_ scale: CGFloat) {
        defer { lastScale = scale }
        guard ZoomDetents.shouldTick(from: lastScale, to: scale, range: ZoomModel.range)
        else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment, performanceTime: .now)
    }
```

(add `import GlassClockCore`; the doc comment and init stay).

- [ ] **Step 4:** Full `swift test` — 73 pass; `swift build` clean.

- [ ] **Step 5: Commit** — `git commit -m "refactor: move zoom detent predicate to core with tests"`

---

### Task 7: LayerClock + AuroraDriftView refactor (app)

**Files:**
- Create: `Sources/GlassClock/LayerClock.swift`
- Modify: `Sources/GlassClock/SolarAuroraLayer.swift` (`setPaused` uses it)

- [ ] **Step 1: Implement** — create `Sources/GlassClock/LayerClock.swift`:

```swift
import QuartzCore

/// The standard CoreAnimation freeze/resume idiom, shared by every
/// design view that animates in the render server.
enum LayerClock {
    static func pause(_ layer: CALayer) {
        let now = layer.convertTime(CACurrentMediaTime(), from: nil)
        layer.speed = 0
        layer.timeOffset = now
    }

    static func resume(_ layer: CALayer) {
        let frozenAt = layer.timeOffset
        layer.speed = 1
        layer.timeOffset = 0
        layer.beginTime = 0
        layer.beginTime = layer.convertTime(CACurrentMediaTime(), from: nil) - frozenAt
    }
}
```

- [ ] **Step 2:** In `Sources/GlassClock/SolarAuroraLayer.swift`, rewrite `setPaused` to:

```swift
    /// Freezes/resumes the render-server clock for this layer.
    func setPaused(_ paused: Bool) {
        guard paused != isPaused else { return }
        isPaused = paused
        if paused {
            LayerClock.pause(aurora)
        } else {
            LayerClock.resume(aurora)
            renderAurora(crossfade: false)  // catch the palette up
        }
    }
```

- [ ] **Step 3:** `swift build` clean; `swift test` 73 pass. Commit — `git commit -m "refactor: shared LayerClock pause idiom"`

---

### Task 8: Caustics design (app)

**Files:**
- Create: `Sources/GlassClock/CausticsLayer.swift`
- Modify: `Sources/GlassClock/GlassDesign.swift` (add + register `CausticsDesign`)

- [ ] **Step 1: Implement** — create `Sources/GlassClock/CausticsLayer.swift`:

```swift
import SwiftUI
import AppKit
import GlassClockCore

/// Sunlight through water: a solar-keyed water gradient with two
/// screen-blended caustic webs drifting over it — all render-server
/// animation, one palette commit per minute.
struct CausticsLayer: NSViewRepresentable {
    var paused: Bool
    func makeNSView(context: Context) -> CausticsSurfaceView { CausticsSurfaceView() }
    func updateNSView(_ view: CausticsSurfaceView, context: Context) {
        view.setPaused(paused)
    }
}

final class CausticsSurfaceView: NSView {
    private let base = CAGradientLayer()
    private let webA = CALayer()
    private let webB = CALayer()
    private var refreshTimer: Timer?
    private var driftSize = NSSize.zero
    private var isPaused = false

    /// One grayscale tile per web, baked once per launch.
    private static let tileA = tileImage(seed: 9)
    private static let tileB = tileImage(seed: 23)

    private static func tileImage(seed: UInt64) -> CGImage {
        let size = 256
        let bytes = CausticsTile.luminance(size: size, seed: seed)
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        return CGImage(
            width: size, height: size,
            bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: size,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider, decode: nil, shouldInterpolate: true,
            intent: .defaultIntent)!
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = true
        base.startPoint = CGPoint(x: 0.5, y: 1)   // layer coords: 1 = top
        base.endPoint = CGPoint(x: 0.5, y: 0)
        layer?.addSublayer(base)
        for (web, tile, opacity) in [(webA, Self.tileA, Float(0.5)),
                                     (webB, Self.tileB, Float(0.35))] {
            web.contents = tile
            web.contentsGravity = .resize
            web.compositingFilter = "screenBlendMode"
            web.opacity = opacity
            layer?.addSublayer(web)
        }
        applyPalette(animated: false)
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.applyPalette(animated: true) }
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    required init?(coder: NSCoder) { fatalError("unused") }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }

    override func layout() {
        super.layout()
        let size = bounds.size
        guard size.width > 0, size.height > 0 else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        base.frame = bounds
        // Webs are oversized so the drift never reveals an edge.
        for web in [webA, webB] {
            web.bounds = CGRect(x: 0, y: 0, width: size.width * 2, height: size.height * 2)
            web.position = CGPoint(x: size.width / 2, y: size.height / 2)
        }
        CATransaction.commit()
        if abs(size.width - driftSize.width) > 1 || abs(size.height - driftSize.height) > 1 {
            driftSize = size
            restartDrift()
        }
    }

    private func applyPalette(animated: Bool) {
        guard !(isPaused && animated) else { return }
        let elevation = SolarPosition.elevation(
            latitude: SolarAuroraLayer.location.latitude,
            longitude: SolarAuroraLayer.location.longitude,
            date: Date())
        let stops = CausticsPalette.colors(forElevation: elevation).map {
            NSColor(red: $0.red, green: $0.green, blue: $0.blue, alpha: 1).cgColor
        }
        CATransaction.begin()
        if animated {
            CATransaction.setAnimationDuration(2)
        } else {
            CATransaction.setDisableActions(true)
        }
        base.colors = stops
        CATransaction.commit()
    }

    /// Two webs wandering on mutually prime periods; their interference
    /// is the shimmer.
    private func restartDrift() {
        func wander(_ keyPath: String, from: Double, to: Double, over seconds: Double) -> CABasicAnimation {
            let animation = CABasicAnimation(keyPath: keyPath)
            animation.fromValue = from
            animation.toValue = to
            animation.duration = seconds
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            return animation
        }
        let w = driftSize.width, h = driftSize.height
        webA.removeAllAnimations()
        webB.removeAllAnimations()
        webA.add(wander("transform.translation.x", from: -w * 0.10, to: w * 0.10, over: 17), forKey: "x")
        webA.add(wander("transform.translation.y", from: -h * 0.06, to: h * 0.06, over: 26), forKey: "y")
        webB.add(wander("transform.translation.x", from: w * 0.08, to: -w * 0.08, over: 19), forKey: "x")
        webB.add(wander("transform.scale", from: 1.0, to: 1.15, over: 31), forKey: "breathe")
    }

    func setPaused(_ paused: Bool) {
        guard paused != isPaused, let layer else { return }
        isPaused = paused
        if paused {
            LayerClock.pause(layer)
        } else {
            LayerClock.resume(layer)
            applyPalette(animated: false)  // catch the water color up
        }
    }
}
```

- [ ] **Step 2:** In `Sources/GlassClock/GlassDesign.swift`, add after `SolarAuroraDesign`:

```swift
/// Sunlight through water: solar-keyed water with drifting caustic webs.
struct CausticsDesign: GlassDesign {
    let id = "caustics"
    let name = "Caustics"
    func ambientLayer(paused: Bool) -> AnyView {
        AnyView(CausticsLayer(paused: paused).opacity(0.35))
    }

    func rimTint(at date: Date) -> Color {
        let accent = CausticsPalette.rimAccent(forElevation: SolarPosition.elevation(
            latitude: SolarAuroraLayer.location.latitude,
            longitude: SolarAuroraLayer.location.longitude,
            date: date))
        return Color(red: accent.red, green: accent.green, blue: accent.blue)
    }
}
```

and register it in the catalog list after `SolarAuroraDesign()`.

- [ ] **Step 3:** `swift build` clean; `swift test` 73 pass. `./make-app.sh` (build only). Commit — `git commit -m "feat: Caustics design — sunlight through water"`

---

### Task 9: Lunar Tide design (app)

**Files:**
- Create: `Sources/GlassClock/LunarTideLayer.swift`
- Modify: `Sources/GlassClock/GlassDesign.swift` (add + register `LunarTideDesign`)

- [ ] **Step 1: Implement** — create `Sources/GlassClock/LunarTideLayer.swift`:

```swift
import SwiftUI
import AppKit
import GlassClockCore

/// A constant night field with a moon glow that follows the real lunar
/// illumination and a slow tidal swell — render-server animation, one
/// moon-brightness commit per minute.
struct LunarTideLayer: NSViewRepresentable {
    var paused: Bool
    func makeNSView(context: Context) -> LunarTideView { LunarTideView() }
    func updateNSView(_ view: LunarTideView, context: Context) {
        view.setPaused(paused)
    }
}

final class LunarTideView: NSView {
    private let base = CAGradientLayer()
    private let moon = CALayer()
    private let swell = CALayer()
    private var refreshTimer: Timer?
    private var driftSize = NSSize.zero
    private var isPaused = false

    /// A soft radial glow, baked once.
    private static let moonGlow: CGImage = {
        let size = 256
        let space = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil, width: size, height: size,
            bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let gradient = CGGradient(
            colorsSpace: space,
            colors: [
                CGColor(red: 1, green: 1, blue: 1, alpha: 0.9),
                CGColor(red: 0.85, green: 0.9, blue: 1, alpha: 0.25),
                CGColor(red: 0.85, green: 0.9, blue: 1, alpha: 0),
            ] as CFArray,
            locations: [0, 0.35, 1])!
        let center = CGPoint(x: size / 2, y: size / 2)
        context.drawRadialGradient(
            gradient, startCenter: center, startRadius: 0,
            endCenter: center, endRadius: CGFloat(size) / 2, options: [])
        return context.makeImage()!
    }()

    /// A wide horizontal luminous band, baked once.
    private static let swellBand: CGImage = {
        let width = 256, height = 64
        let space = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let gradient = CGGradient(
            colorsSpace: space,
            colors: [
                CGColor(red: 0.7, green: 0.8, blue: 1, alpha: 0),
                CGColor(red: 0.7, green: 0.8, blue: 1, alpha: 0.5),
                CGColor(red: 0.7, green: 0.8, blue: 1, alpha: 0),
            ] as CFArray,
            locations: [0, 0.5, 1])!
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: height / 2),
            end: CGPoint(x: width, y: height / 2), options: [])
        return context.makeImage()!
    }()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = true
        base.startPoint = CGPoint(x: 0.5, y: 1)
        base.endPoint = CGPoint(x: 0.5, y: 0)
        base.colors = LunarPalette.field.map {
            NSColor(red: $0.red, green: $0.green, blue: $0.blue, alpha: 1).cgColor
        }
        layer?.addSublayer(base)
        swell.contents = Self.swellBand
        swell.contentsGravity = .resize
        swell.compositingFilter = "screenBlendMode"
        swell.opacity = 0.18
        layer?.addSublayer(swell)
        moon.contents = Self.moonGlow
        moon.contentsGravity = .resize
        layer?.addSublayer(moon)
        applyMoon(animated: false)
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.applyMoon(animated: true) }
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    required init?(coder: NSCoder) { fatalError("unused") }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }

    override func layout() {
        super.layout()
        let size = bounds.size
        guard size.width > 0, size.height > 0 else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        base.frame = bounds
        let moonDiameter = min(size.width, size.height) * 0.9
        moon.bounds = CGRect(x: 0, y: 0, width: moonDiameter, height: moonDiameter)
        moon.position = CGPoint(x: size.width * 0.74, y: size.height * 0.68)
        swell.bounds = CGRect(x: 0, y: 0, width: size.width * 1.5, height: size.height * 0.4)
        swell.position = CGPoint(x: size.width / 2, y: size.height * 0.22)
        CATransaction.commit()
        if abs(size.width - driftSize.width) > 1 || abs(size.height - driftSize.height) > 1 {
            driftSize = size
            restartDrift()
        }
    }

    /// The moon's brightness follows the real illuminated fraction.
    private func applyMoon(animated: Bool) {
        guard !(isPaused && animated) else { return }
        let illumination = LunarPhase.illumination(at: Date())
        CATransaction.begin()
        if animated {
            CATransaction.setAnimationDuration(2)
        } else {
            CATransaction.setDisableActions(true)
        }
        moon.opacity = Float(0.2 + 0.5 * illumination)
        CATransaction.commit()
    }

    private func restartDrift() {
        func wander(_ keyPath: String, from: Double, to: Double, over seconds: Double) -> CABasicAnimation {
            let animation = CABasicAnimation(keyPath: keyPath)
            animation.fromValue = from
            animation.toValue = to
            animation.duration = seconds
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            return animation
        }
        let w = driftSize.width
        moon.removeAllAnimations()
        swell.removeAllAnimations()
        moon.add(wander("transform.translation.x", from: -w * 0.02, to: w * 0.02, over: 53), forKey: "x")
        swell.add(wander("transform.translation.x", from: -w * 0.25, to: w * 0.25, over: 41), forKey: "x")
    }

    func setPaused(_ paused: Bool) {
        guard paused != isPaused, let layer else { return }
        isPaused = paused
        if paused {
            LayerClock.pause(layer)
        } else {
            LayerClock.resume(layer)
            applyMoon(animated: false)
        }
    }
}
```

- [ ] **Step 2:** In `Sources/GlassClock/GlassDesign.swift`, add and register:

```swift
/// A constant night field that follows the real moon.
struct LunarTideDesign: GlassDesign {
    let id = "lunar-tide"
    let name = "Lunar Tide"
    func ambientLayer(paused: Bool) -> AnyView {
        AnyView(LunarTideLayer(paused: paused).opacity(0.45))
    }

    func rimTint(at date: Date) -> Color {
        let accent = LunarPalette.rimAccent(
            illumination: LunarPhase.illumination(at: date))
        return Color(red: accent.red, green: accent.green, blue: accent.blue)
    }
}
```

Catalog order: `[StillGlassDesign(), SolarAuroraDesign(), CausticsDesign(), LunarTideDesign()]`.

- [ ] **Step 3:** `swift build` clean; `swift test` 73 pass; `./make-app.sh`. Commit — `git commit -m "feat: Lunar Tide design — the real moon in the glass"`

---

### Task 10: CI + release workflows, README, version 1.6.0

**Files:**
- Create: `.github/workflows/ci.yml`, `.github/workflows/release.yml`
- Modify: `README.md` (Release section + new designs in the Design bullet), `make-app.sh` (1.6.0 / build 7)

- [ ] **Step 1:** Create `.github/workflows/ci.yml`:

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
jobs:
  test:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: swift test
```

- [ ] **Step 2:** Create `.github/workflows/release.yml`:

```yaml
name: Release
on:
  push:
    tags: ['v*']
permissions:
  contents: write
jobs:
  release:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - name: Verify tag matches the embedded version
        run: |
          EMBEDDED=$(sed -n 's|.*CFBundleShortVersionString</key><string>\(.*\)</string>.*|\1|p' make-app.sh)
          TAG="${GITHUB_REF_NAME#v}"
          if [ "$EMBEDDED" != "$TAG" ]; then
            echo "Tag v$TAG does not match make-app.sh version $EMBEDDED" >&2
            exit 1
          fi
      - name: Run tests
        run: swift test
      - name: Build DMG
        run: ./make-dmg.sh
      - name: Create release
        run: gh release create "$GITHUB_REF_NAME" build/Glass.dmg --generate-notes --title "Glass $GITHUB_REF_NAME"
        env:
          GH_TOKEN: ${{ github.token }}
```

- [ ] **Step 3:** README — in the Design bullet, change the design list to mention all four: `**Still Glass**, **Solar Aurora**, **Caustics** (sunlight through water, tinted by the time of day), and **Lunar Tide** (a night field whose moon glow follows the real lunar phase)`. Add a new section before "Develop":

```markdown
## Release

CI runs `swift test` on every push and PR. To cut a release: bump
`CFBundleShortVersionString` (and `CFBundleVersion`) in `make-app.sh`,
merge to `main`, then tag — the workflow tests, builds `Glass.dmg`, and
publishes a GitHub Release with the DMG attached:

```sh
git tag v1.6.0 && git push origin v1.6.0
```
```

- [ ] **Step 4:** `make-app.sh`: `1.5.0`→`1.6.0`, `CFBundleVersion` `6`→`7`.

- [ ] **Step 5:** `swift test` (73), `./make-app.sh`. Commit — `git commit -m "ci: test + tag-driven DMG release workflows; bump to 1.6.0"`

---

## Spec coverage map

| Spec requirement | Task |
|---|---|
| LunarPhase + LunarPalette (tested) | 1 |
| CausticsTile (tested, tileable, deterministic) | 2 |
| CausticsPalette + shared PaletteMath (tested, aurora behavior pinned) | 3 |
| DragMath / RimLight / ZoomDetents extractions (tested) | 4, 5, 6 |
| Shared LayerClock; AuroraDriftView refactor | 7 |
| Caustics design (render-server, paused, minute palette) | 8 |
| Lunar Tide design (render-server, paused, minute moon) | 9 |
| CI + tag release workflows, README, 1.6.0 | 10 |
