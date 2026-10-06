#!/bin/bash
# Builds build/AppIcon.icns from Resources/icon-art.png.
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="Resources/icon-art.png"
OUT="build/AppIcon.icns"

if [ ! -f "$SRC" ]; then
  echo "error: $SRC not found" >&2
  exit 1
fi

mkdir -p build
swift Scripts/make-icon-from-art.swift "$SRC" build/icon-1024.png

ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for s in 16 32 64 128 256 512; do
  sips -z $s $s build/icon-1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
done
sips -z 32 32    build/icon-1024.png --out "$ICONSET/icon_16x16@2x.png"   >/dev/null
sips -z 64 64    build/icon-1024.png --out "$ICONSET/icon_32x32@2x.png"   >/dev/null
sips -z 128 128  build/icon-1024.png --out "$ICONSET/icon_64x64@2x.png"   >/dev/null
sips -z 256 256  build/icon-1024.png --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 512 512  build/icon-1024.png --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 1024 1024 build/icon-1024.png --out "$ICONSET/icon_512x512@2x.png" >/dev/null

iconutil -c icns "$ICONSET" -o "$OUT"
echo "Built $OUT"
