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
