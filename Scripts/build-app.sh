#!/bin/bash
# Assembles a runnable Spanorama.app bundle from a release SwiftPM build.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
swift build -c "$CONFIG"

BINARY=".build/$CONFIG/Spanorama"
APP="dist/Spanorama.app"

test -x "$BINARY" || { echo "Binary not found at $BINARY" >&2; exit 1; }

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/Spanorama"
cp Resources/Info.plist "$APP/Contents/Info.plist"

if [ ! -f build/AppIcon.icns ]; then
  ./Scripts/make-icon.sh
fi
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc signature so the bundle launches cleanly locally.
codesign --force --sign - "$APP"

echo "Built $APP"
echo "Open with: open $APP"
