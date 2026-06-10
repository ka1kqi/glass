# GlassClock — Design Spec

**Date:** 2026-06-10
**Status:** Approved

## Purpose

A tiny macOS app that displays the current time on a glass (frosted, translucent)
panel floating above all other windows, matching the native macOS aesthetic
exactly — the same live material blur used by Notification Center and the menu
bar, and the San Francisco system font.

## Requirements

- Digital clock showing hours and minutes only (e.g. `9:41`), respecting the
  user's system 12/24-hour setting. No seconds, no date line.
- Genuine macOS glass: `NSVisualEffectView` material blur of whatever is behind
  the window, adapting to light/dark mode automatically.
- Borderless rounded panel (continuous ~24pt corner radius) that floats above
  all windows (`.floating` level), appears on every Space and over fullscreen
  apps.
- Draggable by grabbing anywhere on the panel. Position persists across
  launches via `UserDefaults`.
- Menu-bar-only app (no Dock icon): a clock icon in the menu bar with a single
  menu containing "Quit" (Cmd+Q also works).
- Time updates exactly on each minute boundary via a timer aligned to the next
  minute.

## Architecture

Native Swift/SwiftUI app built with Swift Package Manager — no Xcode project
file, no third-party dependencies.

### Components

| Component | Responsibility |
|---|---|
| `GlassClockApp` / `AppDelegate` | App lifecycle, menu bar status item with Quit menu, creates the panel. |
| `ClockPanel` (`NSPanel` subclass) | Borderless floating panel: window level, collection behavior (all Spaces + fullscreen), drag-anywhere, position persistence. |
| `VisualEffectBackground` | `NSViewRepresentable` wrapping `NSVisualEffectView` (HUD-style material, behind-window blending, rounded corners). |
| `ClockView` (SwiftUI) | Renders the time in SF Rounded, ~96pt, medium weight, with vibrancy. |
| `ClockModel` | Publishes the current time string; owns the minute-aligned timer; formatting logic isolated for testing. |

### Data flow

`ClockModel` computes the formatted time string and the interval to the next
minute boundary → schedules a timer → on fire, updates its published string →
`ClockView` re-renders. No other state except the saved window origin in
`UserDefaults`.

## Error handling

Minimal surface: no network, no file I/O beyond `UserDefaults`. If a saved
position is off-screen (e.g. a monitor was disconnected), the panel falls back
to centered on the main screen.

## Testing

- `swift test` covers `ClockModel`: time formatting (12h and 24h locales) and
  next-minute-boundary interval calculation.
- Visual/overlay behavior (blur, floating, dragging, Spaces) verified manually
  by launching the app.

## Build & run

- `swift build` produces the binary.
- A small `make-app.sh` script wraps the binary into a `GlassClock.app` bundle
  (Info.plist sets `LSUIElement` so there is no Dock icon). No code signing
  required for local use.

## Out of scope (YAGNI)

Analog face, seconds, date display, preferences UI, resizing, multiple clocks,
time zones, login item installation.
