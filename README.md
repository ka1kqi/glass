# Glass

A frosted-glass digital clock that floats above all your windows,
in the native macOS style.

## Install (DMG)

Open `Glass.dmg` and launch Glass from it — the app installs itself to
`/Applications` (replacing an older installed version, or skipping the
copy when the same or newer one is already there) and hands off to the
installed copy, so you never end up with two.

> Downloaded copies are ad-hoc signed; if macOS complains about an
> unidentified developer, right-click the app and choose Open once.

## Build & run

```sh
./make-app.sh
open build/Glass.app
```

Or build a drag-and-drop installer disk image:

```sh
./make-dmg.sh   # produces build/Glass.dmg
```

- Drag the clock anywhere; its position is remembered. Tossing it glides
  with a little inertia, and it settles flush onto nearby screen edges.
- Pinch or scroll on the clock to make it bigger or smaller (0.5x–2.5x);
  it zooms around its center with a haptic tick at natural size, and the
  size is remembered too.
- Right-click the clock (or use the menu bar icon) for the menu. Pick a
  look under Design: **Still Glass** (classic frost), **Solar Aurora** — a
  slow ambient gradient behind the glass, tinted by the real position of
  the sun at your location (computed offline from your timezone; no
  location permission), **Caustics** (sunlight through water, tinted by
  the time of day), and **Lunar Tide** (a night field whose moon glow
  follows the real lunar phase). The glass edge catches light from your
  cursor, and a subtle sheen sweeps across each minute change.
- The same menu has settings, all remembered across launches: Float Above
  Windows (off parks the clock behind your windows, like a desk
  accessory), Keep Mac Awake (`caffeinate`), Keep Display Awake
  (`caffeinate -d`), Lighting Effects (the cursor-lit rim and minute
  sheen), and an off-by-default Hourly Chime (a soft synthesized glass
  ting).
- Effectively zero CPU at rest: the aurora drifts as a render-server
  animation and the rim light is driven by mouse events, so the app does
  no per-frame work. Ambient effects also pause automatically when the
  clock is hidden, dragged, the screen sleeps, Low Power Mode is on, or
  Reduce Motion is set.
- Follows your system 12/24-hour setting; adapts to light/dark mode.
  Requires macOS 15.

## Release

CI runs `swift test` on every push and PR. To cut a release: bump
`CFBundleShortVersionString` (and `CFBundleVersion`) in `make-app.sh`,
merge to `main`, then tag — the workflow tests, builds `Glass.dmg`, and
publishes a GitHub Release with the DMG attached:

    git tag v1.6.1 && git push origin v1.6.1

## Develop

```sh
swift test    # unit tests (Swift Testing)
swift build   # debug build at .build/debug/GlassClock
```
