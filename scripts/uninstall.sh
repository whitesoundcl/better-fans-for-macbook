#!/bin/bash
# Restores automatic fan control and removes the helper. Run: sudo scripts/uninstall.sh
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
LABEL=com.whitesound.fanbar.helper
launchctl bootout system/$LABEL 2>/dev/null || true   # helper restores auto on SIGTERM
rm -f /Library/LaunchDaemons/$LABEL.plist /Library/PrivilegedHelperTools/$LABEL
"$(dirname "$0")/../dist/fanctl" auto 2>/dev/null || true
echo "Helper removed; fans back under macOS control."
