# Living Glass — Design Spec

**Date:** 2026-06-10
**Status:** Approved

## Purpose

Make Glass feel alive. The frosted panel stops being static frost and starts
reflecting the world: an ambient light layer tinted by the real position of the
sun, a glass edge that catches light from the cursor, a glint when the minute
changes, and physical behaviors (corner snapping, toss inertia, haptic zoom
detents, an optional hourly chime). Ambient looks are built as a pluggable
**design system**: Glass ships with two designs and the architecture makes
adding many more cheap, with selection in the status-bar menu.

Design principles (from research into Apple Liquid Glass, Linear/Raycast-style
ambient UI, and component-gallery lighting recipes):

- **Tiny alphas, huge geometry, slow time.** Ambient light peaks around 8%
  opacity and moves over tens of seconds. The effects sit at the threshold of
  perception.
- **The digits always win.** Legibility beats spectacle; every effect renders
  behind or around the time, never over it.
- **Free at rest.** When nothing should animate (occluded, asleep, Low Power
  Mode, Reduce Motion), Glass costs what it costs today.

## Platform decision

The package minimum rises from macOS 13 to **macOS 15**: `MeshGradient`
(macOS 15) powers the aurora and SwiftUI Metal shaders (macOS 14) are available
for future designs. One render path, no fallbacks.

## Requirements

### Design system

- A `GlassDesign` protocol: a design has a stable `id` (persisted), a display
  `name`, and an ambient SwiftUI layer builder. (Per-design accent parameters
  for the rim/glint overlays are deferred until a design needs them — YAGNI.)
- A `DesignCatalog` listing available designs in menu order.
- Selection persists in `UserDefaults` (key `GlassDesign`); unknown/missing ids
  fall back to the default design.
- Status-bar menu gains a **Design** submenu with one checkmarked item per
  catalog entry; switching applies immediately with a short cross-fade.
- Ships with two designs:
  - **Still Glass** — today's look exactly: no ambient layer. The default.
  - **Solar Aurora** — the living-glass flagship, below.

### Solar Aurora design

- A 3×3 `MeshGradient` rendered between the `VisualEffectBackground` and the
  clock text at low opacity (~20% max). Interior/edge points drift on slow
  independent sine orbits so the field never repeats visibly.
- Driven by `TimelineView(.animation(minimumInterval: 1/15, paused:))` — 15 fps
  ceiling, paused per the energy rules below.
- The palette interpolates continuously between keyframes anchored to **solar
  elevation**, not clock hours:
  - Night (elevation ≤ −12°): near-black indigo with faint violet.
  - Dawn/dusk band (−12°…0°): indigo → mauve → dusty rose.
  - Golden hour (0°…+10°): coral → ember → honey amber.
  - Day (≥ +25°): cool, nearly neutral blue-white.
  - Linear interpolation between adjacent anchors; rising vs. setting does not
    matter, only elevation (symmetric, like natural light).
- Solar elevation computed **locally, no network, no location permission**:
  NOAA/SPA-style solar position math vendored into `GlassClockCore`, with
  latitude/longitude approximated from the system timezone identifier. A wrong
  guess degrades gracefully (the palette shifts by at most an hour or two).
- Finished with a static film-grain overlay at ~4% opacity (noise image baked
  once at launch) so gradients dissolve into grain instead of banding.

### Specular rim (all designs, including Still Glass)

- The panel's hairline rim brightens on the side facing the mouse cursor —
  anywhere on the desktop — as if the cursor were a light source.
- Implementation: the shared ambient timeline polls `NSEvent.mouseLocation`
  (no global event monitor, no permissions), computes the angle from panel
  center to cursor, and renders a soft `AngularGradient` arc masked to a 1pt
  `strokeBorder` of the panel shape.
- Intensity falls off with cursor distance (full within ~150pt of the rim,
  fading to invisible beyond ~600pt). When the cursor is far, the rim is the
  plain hairline and the poll is the only cost.

### Minute glint (all designs)

- When the displayed time changes, a diagonal bar of white light sweeps once
  across the panel: ~650 ms, 45°, slightly blurred, ~8% peak opacity, masked
  to the glass shape. Triggered by the existing `ClockModel` minute tick; never
  loops, and never fires while ambient animation is paused.

### Energy discipline

- One shared `AmbientPacer` object owns the `paused` flag for all animated
  layers. It pauses when any of these hold:
  - the panel is not visible (`NSWindow.occlusionState` lacks `.visible`),
  - the screen is asleep / system is going to sleep (`NSWorkspace`
    notifications; resume on wake — wiring exists in `refreshOnWake`),
  - Low Power Mode (`ProcessInfo.isLowPowerModeEnabled`, observed via
    `NSProcessInfoPowerStateDidChange`),
  - Reduce Motion (`NSWorkspace.accessibilityDisplayShouldReduceMotion`) —
    this also disables the glint sweep and toss inertia.
- Ambient layers never exceed 15 fps. The clock digits keep their existing
  minute-aligned update; nothing else runs per-frame.

### Physical delight

- **Corner/edge snap:** on drag release, if the panel is within ~24pt of a
  screen edge or corner (relative to `visibleFrame`), it settles onto the edge
  with a soft spring animation. Snapping never fights the user mid-drag.
- **Toss inertia:** drag velocity at release carries the panel a short glide
  with quick decay (subtle — a few points, not a hockey puck), then the snap
  rule applies to where it lands.
- **Haptic zoom detents:** `NSHapticFeedbackManager` performs an `.alignment`
  tick when the zoom scale crosses 1.0× and when it hits the 0.5×/2.5× limits.
- **Hourly chime:** optional, **off by default**, toggled from the status-bar
  menu (persisted in `UserDefaults`). On the hour, a soft glass "ting" —
  synthesized at runtime with `AVAudioEngine` (decaying sine partials, like
  tapping a wineglass), no bundled audio asset. Respects the system output
  device. Audio pauses only for sleep and Low Power Mode — occlusion and
  Reduce Motion are visual concerns and do not mute an explicitly enabled
  chime.

## Architecture

```
ClockView (layer stack, bottom → top)
  VisualEffectBackground      existing behind-window blur, unchanged
  AmbientDesignLayer          selected GlassDesign's view, low opacity
  GrainOverlay                static noise, ~4%
  Time text                   existing
  MinuteGlintOverlay          one-shot sweep on minute change
  SpecularRimOverlay          cursor-lit arc on the hairline rim (topmost,
                              so the hairline is never washed by the glint)
```

### Components

| Component | Module | Responsibility |
|---|---|---|
| `GlassDesign` / `DesignCatalog` | app | Design protocol, registry, menu order. |
| `DesignModel` | app | Published selected design; `UserDefaults` persistence (pattern: `ZoomModel`). |
| `SolarAuroraLayer` | app | Animated `MeshGradient` view for the flagship design. |
| `SolarPosition` | core | Pure solar-elevation math: (lat, lon, date) → elevation degrees. Unit-tested. |
| `AuroraPalette` | core | Elevation → mesh color array interpolation. Unit-tested. |
| `TimeZoneLocation` | core | Timezone identifier → approximate (lat, lon). Unit-tested. |
| `AmbientPacer` | app | Single source of truth for the `paused` flag (occlusion, sleep, low power, reduce motion). |
| `SpecularRimOverlay` | app | Mouse-angle arc on the rim stroke. |
| `MinuteGlintOverlay` | app | One-shot sweep keyed off `ClockModel` updates. |
| `GrainOverlay` | app | Noise texture baked once at launch. |
| `SnapBehavior` | core (math) + app (animation) | Snap-target math (frame, screen, threshold) → snapped origin. Math unit-tested. |
| `TossBehavior` | app | Velocity tracking in `ClockPanel`, decay glide on release. |
| `ZoomHaptics` | app | Detent detection on `ZoomModel.scale` crossings. |
| `Chime` | app | `AVAudioEngine` glass-ting synth + hour scheduling. |

### Data flow

`AmbientPacer` publishes `paused` → all `TimelineView`s take it as their
`paused:` argument. `DesignModel` publishes the selected design → `ClockView`
swaps the ambient layer with a cross-fade. The aurora recomputes solar
elevation inside its 15 fps timeline (a handful of trig calls — cheaper than
plumbing a separate minute hook); mesh point drift is purely time-based.

## Error handling

- Timezone with no location mapping → fall back to elevation from UTC offset
  (crude but harmless; palette still cycles daily).
- `AVAudioEngine` failure → chime silently disabled; no alert for a decoration.
- All persistence keys are optional with sensible defaults (design: Still
  Glass; chime: off).

## Testing

- `swift test` (Swift Testing) covers the new core logic:
  - `SolarPosition`: known ephemeris cases (e.g. equinox noon at the equator
    ≈ 90°, polar night negative all day).
  - `AuroraPalette`: anchor elevations return anchor palettes; midpoints
    interpolate; out-of-range clamps.
  - `TimeZoneLocation`: representative identifiers map to plausible coords.
  - `SnapBehavior`: inside/outside threshold, corners vs. edges, multi-screen
    `visibleFrame` respected.
- Visual layers (aurora look, rim, glint, grain) and feel (snap, toss,
  haptics, chime) verified manually — they are aesthetic judgments.
- Energy: spot-check with `powermetrics --samplers gpu_power` that Still Glass
  matches today's idle cost and Solar Aurora stays within a few % GPU.

## Out of scope (YAGNI)

Additional designs beyond the first two (the system exists; the catalog grows
later), caustic shimmer, hourly rim comet, timers/pomodoro, calendar
integration, multiple clocks/timezones, a settings window (the menu suffices),
real Liquid Glass APIs (macOS 26), location permission prompts, networked
anything.
