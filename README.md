# GlassClock

A frosted-glass digital clock that floats above all your windows,
in the native macOS style.

## Build & run

```sh
./make-app.sh
open build/GlassClock.app
```

- Drag the clock anywhere; its position is remembered.
- Quit from the clock icon in the menu bar.
- Follows your system 12/24-hour setting; adapts to light/dark mode.

## Develop

```sh
swift test    # unit tests (Swift Testing)
swift build   # debug build at .build/debug/GlassClock
```
