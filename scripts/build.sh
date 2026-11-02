#!/bin/bash
# Builds release binaries and packages "dist/Better Fans For Macbook.app" (menu bar app, no Dock icon).
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN=$(swift build -c release --show-bin-path)

APP="dist/Better Fans For Macbook.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN/BetterFans" "$APP/Contents/MacOS/BetterFans"
cp "$BIN/fanhelperd" dist/fanhelperd 2>/dev/null || { mkdir -p dist && cp "$BIN/fanhelperd" dist/fanhelperd; }
cp "$BIN/fanctl" dist/fanctl

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.whitesound.betterfans</string>
  <key>CFBundleName</key><string>Better Fans For Macbook</string>
  <key>CFBundleDisplayName</key><string>Better Fans For Macbook</string>
  <key>CFBundleExecutable</key><string>BetterFans</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST

codesign --force --sign - "$APP"
echo "Built $APP, dist/fanhelperd, dist/fanctl"
