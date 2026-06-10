# GlassClock Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A menu-bar-only macOS app that floats a frosted-glass digital clock (hours:minutes) above all windows, draggable, with position persistence.

**Architecture:** Swift Package Manager executable. A small `GlassClockCore` library holds the testable logic (time formatting, minute-boundary math, the published clock model); the `GlassClock` executable holds the AppKit/SwiftUI shell (borderless floating `NSPanel`, `NSVisualEffectView` glass, status-bar item). A shell script wraps the release binary into a `.app` bundle.

**Tech Stack:** Swift 6.1 (Command Line Tools only — no Xcode), SwiftUI + AppKit, Swift Testing (`import Testing`, NOT XCTest — XCTest is unavailable without full Xcode), Swift Package Manager.

**Working directory:** `/Users/kai/Documents/GitHub/glass-clock` (existing git repo; specs/plans already committed).

**Spec:** `docs/superpowers/specs/2026-06-10-glass-clock-design.md`

---

## File Structure

```
Package.swift                                  — SPM manifest (3 targets)
Sources/GlassClockCore/ClockFormatter.swift    — pure formatting + minute-boundary math
Sources/GlassClockCore/ClockModel.swift        — ObservableObject publishing the time string
Sources/GlassClock/main.swift                  — entry point
Sources/GlassClock/AppDelegate.swift           — status item, panel creation, position restore
Sources/GlassClock/ClockPanel.swift            — borderless floating NSPanel
Sources/GlassClock/VisualEffectBackground.swift— NSVisualEffectView wrapper (the glass)
Sources/GlassClock/ClockView.swift             — SwiftUI time display
Tests/GlassClockCoreTests/ClockFormatterTests.swift
Tests/GlassClockCoreTests/ClockModelTests.swift
make-app.sh                                    — wraps binary into GlassClock.app
.gitignore
```

---

### Task 1: Package scaffold

**Files:**
- Create: `Package.swift`
- Create: `.gitignore`
- Create: `Sources/GlassClockCore/ClockFormatter.swift` (empty stub so the target builds)
- Create: `Sources/GlassClock/main.swift` (stub)

- [ ] **Step 1: Write `Package.swift`**

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "GlassClock",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "GlassClockCore"),
        .executableTarget(name: "GlassClock", dependencies: ["GlassClockCore"]),
        .testTarget(name: "GlassClockCoreTests", dependencies: ["GlassClockCore"]),
    ]
)
```

- [ ] **Step 2: Write `.gitignore`**

```
.build/
build/
.DS_Store
```

- [ ] **Step 3: Write stub sources**

`Sources/GlassClockCore/ClockFormatter.swift`:

```swift
import Foundation

public enum ClockFormatter {}
```

`Sources/GlassClock/main.swift`:

```swift
import Foundation

// AppKit entry point added in Task 5.
```

- [ ] **Step 4: Verify it builds**

Run: `swift build`
Expected: `Build complete!` (warnings OK, no errors)

- [ ] **Step 5: Commit**

```bash
git add Package.swift .gitignore Sources
git commit -m "chore: scaffold SPM package with core, app, and test targets"
```

---

### Task 2: ClockFormatter (TDD)

**Files:**
- Create: `Tests/GlassClockCoreTests/ClockFormatterTests.swift`
- Modify: `Sources/GlassClockCore/ClockFormatter.swift`

- [ ] **Step 1: Write the failing tests**

`Tests/GlassClockCoreTests/ClockFormatterTests.swift`:

```swift
import Foundation
import Testing
@testable import GlassClockCore

private func makeDate(hour: Int, minute: Int, second: Int) -> Date {
    var components = DateComponents()
    components.year = 2026
    components.month = 6
    components.day = 10
    components.hour = hour
    components.minute = minute
    components.second = second
    return Calendar.current.date(from: components)!
}

@Test func twelveHourLocaleDropsLeadingZeroAndPeriod() {
    let s = ClockFormatter.timeString(
        for: makeDate(hour: 21, minute: 41, second: 0),
        locale: Locale(identifier: "en_US"))
    #expect(s == "9:41")
}

@Test func twentyFourHourLocaleUsesFullHours() {
    let s = ClockFormatter.timeString(
        for: makeDate(hour: 21, minute: 41, second: 0),
        locale: Locale(identifier: "de_DE"))
    #expect(s == "21:41")
}

@Test func twentyFourHourLocalePadsMorningHours() {
    let s = ClockFormatter.timeString(
        for: makeDate(hour: 9, minute: 5, second: 0),
        locale: Locale(identifier: "de_DE"))
    #expect(s == "09:05")
}

@Test func intervalFromMidMinuteReachesNextBoundary() {
    let i = ClockFormatter.intervalToNextMinute(
        from: makeDate(hour: 9, minute: 41, second: 30))
    #expect(abs(i - 30) < 0.001)
}

@Test func intervalFromExactBoundaryIsFullMinute() {
    let i = ClockFormatter.intervalToNextMinute(
        from: makeDate(hour: 9, minute: 41, second: 0))
    #expect(abs(i - 60) < 0.001)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test`
Expected: FAIL — compile errors like `type 'ClockFormatter' has no member 'timeString'`

- [ ] **Step 3: Implement `ClockFormatter`**

Replace `Sources/GlassClockCore/ClockFormatter.swift` with:

```swift
import Foundation

public enum ClockFormatter {
    /// Whether the locale (which reflects the user's system 12/24-hour
    /// setting when `.autoupdatingCurrent`) uses a 24-hour clock.
    public static func is24Hour(locale: Locale = .autoupdatingCurrent) -> Bool {
        let format = DateFormatter.dateFormat(
            fromTemplate: "j", options: 0, locale: locale) ?? "h"
        return !format.contains("a")
    }

    /// Lock-screen style time: "9:41" in 12-hour locales, "21:41" in 24-hour.
    public static func timeString(
        for date: Date,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = is24Hour(locale: locale) ? "HH:mm" : "h:mm"
        return formatter.string(from: date)
    }

    /// Seconds until the next minute boundary (60 if exactly on one).
    public static func intervalToNextMinute(from date: Date) -> TimeInterval {
        let next = Calendar.current.nextDate(
            after: date,
            matching: DateComponents(second: 0),
            matchingPolicy: .nextTime)!
        return next.timeIntervalSince(date)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: `Test run with 5 tests passed`

- [ ] **Step 5: Commit**

```bash
git add Sources/GlassClockCore/ClockFormatter.swift Tests
git commit -m "feat: add ClockFormatter with locale-aware time and minute-boundary math"
```

---

### Task 3: ClockModel (TDD)

**Files:**
- Create: `Tests/GlassClockCoreTests/ClockModelTests.swift`
- Create: `Sources/GlassClockCore/ClockModel.swift`

- [ ] **Step 1: Write the failing test**

`Tests/GlassClockCoreTests/ClockModelTests.swift`:

```swift
import Foundation
import Testing
@testable import GlassClockCore

@Test @MainActor func modelStartsWithFormattedCurrentTime() {
    let model = ClockModel()
    #expect(model.timeString.range(
        of: #"^\d{1,2}:\d{2}$"#, options: .regularExpression) != nil)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test`
Expected: FAIL — compile error `cannot find 'ClockModel' in scope`

- [ ] **Step 3: Implement `ClockModel`**

`Sources/GlassClockCore/ClockModel.swift`:

```swift
import Foundation
import Combine

/// Publishes the current "9:41"-style time string, updating just after
/// each minute boundary.
@MainActor
public final class ClockModel: ObservableObject {
    @Published public private(set) var timeString: String

    // The loop holds self weakly, so it exits on its own after the model
    // is deallocated; no deinit cancellation needed (deinit cannot touch
    // MainActor state under Swift 6 anyway).
    private var tickLoop: Task<Void, Never>?

    public init() {
        timeString = ClockFormatter.timeString(for: Date())
        tickLoop = Task { [weak self] in
            while true {
                let interval = ClockFormatter.intervalToNextMinute(from: Date())
                // +50ms so we land safely past the boundary.
                try? await Task.sleep(
                    nanoseconds: UInt64((interval + 0.05) * 1_000_000_000))
                guard let self else { return }
                self.timeString = ClockFormatter.timeString(for: Date())
            }
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: `Test run with 6 tests passed`

- [ ] **Step 5: Commit**

```bash
git add Sources/GlassClockCore/ClockModel.swift Tests/GlassClockCoreTests/ClockModelTests.swift
git commit -m "feat: add ClockModel publishing minute-aligned time updates"
```

---

### Task 4: Glass background and clock view

**Files:**
- Create: `Sources/GlassClock/VisualEffectBackground.swift`
- Create: `Sources/GlassClock/ClockView.swift`

No unit tests — pure view code, verified visually in Task 6. Compile check only.

- [ ] **Step 1: Write `VisualEffectBackground.swift`**

```swift
import SwiftUI
import AppKit

/// The real macOS glass: blurs whatever is behind the window, adapting to
/// light/dark mode, with a continuous rounded-corner mask.
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 24
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
```

- [ ] **Step 2: Write `ClockView.swift`**

```swift
import SwiftUI
import GlassClockCore

struct ClockView: View {
    @ObservedObject var model: ClockModel

    var body: some View {
        Text(model.timeString)
            .font(.system(size: 88, weight: .medium, design: .rounded))
            .foregroundStyle(.primary)
            .frame(width: 340, height: 150)
            .background(VisualEffectBackground())
    }
}
```

- [ ] **Step 3: Verify it builds**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 4: Commit**

```bash
git add Sources/GlassClock
git commit -m "feat: add glass visual-effect background and SwiftUI clock view"
```

---

### Task 5: Floating panel, status item, app entry

**Files:**
- Create: `Sources/GlassClock/ClockPanel.swift`
- Create: `Sources/GlassClock/AppDelegate.swift`
- Modify: `Sources/GlassClock/main.swift`

- [ ] **Step 1: Write `ClockPanel.swift`**

```swift
import AppKit

/// Borderless glass panel that floats above all windows, on every Space
/// and over fullscreen apps, draggable from anywhere on its surface.
final class ClockPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
```

- [ ] **Step 2: Write `AppDelegate.swift`**

```swift
import AppKit
import SwiftUI
import GlassClockCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: ClockPanel!
    private var statusItem: NSStatusItem!
    private let model = ClockModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setUpPanel()
        setUpStatusItem()
    }

    private func setUpPanel() {
        let size = NSSize(width: 340, height: 150)
        panel = ClockPanel(contentRect: NSRect(origin: .zero, size: size))
        panel.contentView = NSHostingView(rootView: ClockView(model: model))
        panel.setFrameAutosaveName("GlassClockPanel")
        if !isOnAnyScreen(panel.frame) {
            panel.center()
        }
        panel.orderFrontRegardless()
    }

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "clock", accessibilityDescription: "GlassClock")
        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: "Quit GlassClock",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func isOnAnyScreen(_ frame: NSRect) -> Bool {
        NSScreen.screens.contains { $0.visibleFrame.intersects(frame) }
    }
}
```

- [ ] **Step 3: Replace `main.swift`**

```swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
```

- [ ] **Step 4: Verify it builds and tests still pass**

Run: `swift build && swift test`
Expected: `Build complete!`, `Test run with 6 tests passed`

- [ ] **Step 5: Smoke-test the binary**

Run: `.build/debug/GlassClock & sleep 3 && ps -p $! && kill $!`
Expected: process is alive after 3 seconds (no crash). A glass clock panel
appears on screen during the test. (Run from a session with screen access;
if running headless, the alive-check still validates no launch crash.)

- [ ] **Step 6: Commit**

```bash
git add Sources/GlassClock
git commit -m "feat: add floating clock panel, status-bar item, and app entry point"
```

---

### Task 6: App bundle script and manual verification

**Files:**
- Create: `make-app.sh`
- Create: `README.md`

- [ ] **Step 1: Write `make-app.sh`**

```bash
#!/bin/bash
# Builds GlassClock and wraps it into build/GlassClock.app.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP=build/GlassClock.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/GlassClock "$APP/Contents/MacOS/GlassClock"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>GlassClock</string>
    <key>CFBundleIdentifier</key><string>local.glassclock</string>
    <key>CFBundleName</key><string>GlassClock</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

codesign --force --sign - "$APP" 2>/dev/null || true
echo "Built $APP — launch with: open $APP"
```

- [ ] **Step 2: Make it executable and run it**

Run: `chmod +x make-app.sh && ./make-app.sh`
Expected: `Built build/GlassClock.app — launch with: open build/GlassClock.app`

- [ ] **Step 3: Write `README.md`**

```markdown
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
```

- [ ] **Step 4: Manual verification checklist** (needs a human or screen access)

Run: `open build/GlassClock.app`, then verify:
- Glass panel appears showing the current time, blurring what's behind it
- No Dock icon; clock icon present in the menu bar
- Panel can be dragged anywhere; floats above other app windows
- After quitting (menu bar icon → Quit GlassClock) and relaunching, the panel reappears at the dragged-to position
- Time text adapts when switching light/dark mode (System Settings → Appearance)

- [ ] **Step 5: Commit**

```bash
git add make-app.sh README.md
git commit -m "feat: add app bundle build script and README"
```

---

## Self-Review Notes

- Spec coverage: digital HH:MM (Task 2), system 12/24h (Task 2), real glass + rounded corners (Task 4), floating/all-Spaces/fullscreen + drag + position persistence with off-screen fallback (Task 5), menu-bar-only with Quit (Task 5), minute-aligned updates (Task 3), `.app` bundle with `LSUIElement` (Task 6), tests for formatting + boundary math (Tasks 2–3). No gaps.
- XCTest is intentionally absent: this machine has Command Line Tools only; Swift Testing was verified working (probe package, 2026-06-10).
- Position persistence uses `NSWindow.setFrameAutosaveName` (UserDefaults-backed), satisfying the spec's UserDefaults requirement.
