#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$PWD"
(cd AIUsageBar && swift build -c release)
BIN="$(cd AIUsageBar && swift build -c release --show-bin-path)/AIUsageBar"
APP="$ROOT/build/AIUsageBar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/AIUsageBar"
cp assets/icon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>AIUsageBar</string>
<key>CFBundleIdentifier</key><string>group.dwelly.aiusagebar</string>
<key>CFBundleName</key><string>AI Usage Bar</string>
<key>CFBundleDisplayName</key><string>AI Usage Bar</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSUIElement</key><true/>
<key>LSMinimumSystemVersion</key><string>13.0</string>
</dict></plist>
PL
codesign --force --deep -s - "$APP"
mkdir -p ~/Applications
rm -rf ~/Applications/AIUsageBar.app
cp -R "$APP" ~/Applications/AIUsageBar.app
echo "Installed ~/Applications/AIUsageBar.app"
