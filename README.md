# Glass

A frosted-glass digital clock that floats above all your windows,
in the native macOS style.

## Install (DMG)

Open `Glass.dmg` and launch Glass from it — the app installs itself to
`/Applications` on first run (it skips the copy if it's already installed)
and hands off to the installed copy, so you never end up with two.

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

- Drag the clock anywhere; its position is remembered.
- Pinch or scroll on the clock to make it bigger or smaller (0.5x–2.5x);
  it zooms around its center and the size is remembered too.
- The menu bar clock icon has settings: Keep Mac Awake (`caffeinate`) and
  Keep Display Awake (`caffeinate -d`), both remembered across launches
  and active only while Glass runs. Quit from the same menu.
- Follows your system 12/24-hour setting; adapts to light/dark mode.

## Develop

```sh
swift test    # unit tests (Swift Testing)
swift build   # debug build at .build/debug/GlassClock
```
