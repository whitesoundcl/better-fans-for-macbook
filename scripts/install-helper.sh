#!/bin/bash
# Installs the privileged fan helper as a LaunchDaemon. Run: sudo scripts/install-helper.sh
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
cd "$(dirname "$0")/.."

LABEL=com.whitesound.betterfans.helper
DEST=/Library/PrivilegedHelperTools/$LABEL
PLIST=/Library/LaunchDaemons/$LABEL.plist
[ -x dist/fanhelperd ] || { echo "run scripts/build.sh first"; exit 1; }

launchctl bootout system/$LABEL 2>/dev/null || true
mkdir -p /Library/PrivilegedHelperTools
cp dist/fanhelperd "$DEST"
chown root:wheel "$DEST"; chmod 755 "$DEST"
codesign --force --sign - "$DEST"

cat > "$PLIST" <<XML
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$DEST</string></array>
  <key>MachServices</key><dict><key>$LABEL</key><true/></dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict></plist>
XML
chown root:wheel "$PLIST"; chmod 644 "$PLIST"
launchctl bootstrap system "$PLIST"
echo "Helper installed and running."
