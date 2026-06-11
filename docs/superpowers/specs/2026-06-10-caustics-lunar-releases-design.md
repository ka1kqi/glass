# Caustics, Lunar Tide, Releases & Core Hardening — Design Spec

**Date:** 2026-06-10
**Status:** Approved

## Purpose

Two new glass designs built on the zero-CPU render-server architecture
(Caustics: sunlight through water; Lunar Tide: a night field that follows
the real moon), proper release automation (CI + tag-driven DMG releases),
and tests for the remaining untested pure math (drag velocity, rim light,
zoom detents) by moving it into `GlassClockCore`.

Performance bar (non-negotiable, inherited from the overhaul): designs do
no per-frame app work. Motion is render-server animation; the app commits
at most once a minute.

## Requirements

### Caustics design

- **Visual:** a water-colored vertical gradient tinted by solar elevation
  (bright aqua at midday → teal dusk → deep navy night), with two
  screen-blended layers of drifting caustic light-webs over it — the
  classic two-field interference fake from the research.
- **Core math (`CausticsTile`, tested):** a deterministic, seamlessly
  tileable grayscale caustics field — Voronoi cell-edge brightness
  (`(1 − clamp((F2−F1)·lineScale))^sharpness`) with toroidal distance so
  edges wrap, seeded pseudo-random feature points. Tests: determinism,
  seed variation, luminance range, statistical wrap-continuity.
- **Core palette (`CausticsPalette`, tested):** 3-stop water gradient
  keyed to solar elevation with the same anchor-interpolation scheme as
  `AuroraPalette`, plus `rimAccent(forElevation:)` (mid color lifted 60%
  toward white).
- **App (`CausticsSurfaceView`):** base `CAGradientLayer` (palette
  refreshed once a minute, 2s crossfade) + two oversized caustic tile
  layers (`compositingFilter` screen blend, opacities ~0.5/0.35) drifting
  on repeating transform animations with mutually prime periods (17s/26s
  translate, 31s scale breathe on the second). Pause = the layer-clock
  freeze idiom. Registered as id `caustics`, name "Caustics".

### Lunar Tide design

- **Visual:** a constant deep-indigo night field (its identity — it does
  NOT follow the sun), a soft moon-glow orb whose brightness follows the
  real lunar illumination, drifting almost imperceptibly, and a slow
  luminous swell band crossing low in the panel like a tide.
- **Core math (`LunarPhase`, tested):** mean synodic approximation —
  phase fraction in [0,1) from the 2000-01-06 18:14 UTC new-moon epoch
  and the 29.53058867d synodic month; `illumination(at:)` =
  `(1 − cos(2π·phase))/2`. Tests: the 2000-01-21 full moon (lunar eclipse
  date), the following new moon, illumination endpoints, periodicity.
- **Core palette (`LunarPalette`, tested):** the indigo field colors and
  `rimAccent(illumination:)` — silver-blue moonlight, brighter when the
  moon is fuller (lift toward white scales 0.35→0.7 with illumination).
- **App (`LunarTideView`):** static indigo gradient base; pre-rendered
  radial moon-glow image layer (opacity 0.2 + 0.5·illumination, updated
  once a minute) on a slow drift orbit; one wide soft band layer
  translating across the lower third (41s period, low opacity). Pause =
  layer-clock freeze. Registered as id `lunar-tide`, name "Lunar Tide".

### Shared plumbing

- The CA pause/resume (speed/timeOffset/beginTime) idiom moves to a
  shared `LayerClock` helper; `AuroraDriftView` refactors onto it.

### Proper releases

- **CI workflow** (`.github/workflows/ci.yml`): `swift test` on every
  push and pull request to `main`, on a macOS 15 runner.
- **Release workflow** (`.github/workflows/release.yml`): on pushing a
  tag `v*`: run tests, verify the tag matches the version embedded in
  `make-app.sh` (fail loudly on drift), build `Glass.dmg` via
  `./make-dmg.sh`, and create a GitHub Release with the DMG attached and
  generated notes. Ad-hoc signing (status quo for this project).
- README gains a "Release" section documenting the flow: bump version in
  `make-app.sh`, merge, `git tag vX.Y.Z && git push origin vX.Y.Z`.

### Core hardening (move + test the remaining pure math)

- `DragMath.releaseVelocity(samples:releasedAt:)` — from `ClockPanel`;
  tests: flick-then-hold returns zero, normal flick velocity, single
  sample, empty samples.
- `RimLight.compute(panel:mouse:)` — from `SpecularRimOverlay.light`;
  tests: four cardinal directions (angle sign convention), intensity 1
  inside/near, 0 beyond 600pt, monotonic falloff, nil panel.
- `ZoomDetents.shouldTick(from:to:range:)` — the crossing/limit predicate
  from `ZoomHaptics`; tests: cross up/down, exact landing on 1.0 from
  both directions, limit arrival once, mid-range silence, no-change.
- App callers delegate to core; behavior is identical (the app-side
  types keep AppKit concerns: haptics performer, NSEvent, monitors).

## Out of scope (YAGNI)

Sparkle/notarized updates, Liquid Glass (macOS 26) adoption, design
previews in the menu, moon position/azimuth astronomy (illumination only),
GPU shaders. Version bumps to 1.6.0 with this release.

## Testing

All new core logic TDD'd in `Tests/GlassClockCoreTests` (Swift Testing).
Designs verified visually; CPU re-measured (target: same 0.0% idle as
Solar Aurora). Workflows verified by pushing the tag for 1.6.0 after
merge and confirming the release appears with the DMG attached.
