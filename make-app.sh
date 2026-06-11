#!/bin/bash
# Builds Glass and wraps it into build/Glass.app.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP=build/Glass.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/GlassClock "$APP/Contents/MacOS/Glass"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Glass</string>
    <key>CFBundleIdentifier</key><string>local.glass</string>
    <key>CFBundleName</key><string>Glass</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.3.0</string>
    <key>CFBundleVersion</key><string>4</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

codesign --force --sign - "$APP" 2>/dev/null || true
echo "Built $APP — launch with: open $APP"
