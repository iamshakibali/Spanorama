#!/bin/bash
# Spanorama installer: downloads the latest release and installs it to /Applications.
#
#   curl -fsSL https://raw.githubusercontent.com/iamshakibali/Spanorama/main/Scripts/install.sh | bash
#
set -euo pipefail

REPO="iamshakibali/Spanorama"
APP_NAME="Spanorama.app"
DEST="/Applications"

info()  { printf '\033[1;36m==>\033[0m %s\n' "$1"; }
error() { printf '\033[1;31merror:\033[0m %s\n' "$1" >&2; exit 1; }

if [ "$(uname -s)" != "Darwin" ]; then
  error "This installer is for macOS only."
fi

if [ "$(uname -m)" != "arm64" ]; then
  info "Warning: current releases are built for Apple Silicon (arm64) only."
fi

TMP="$(mktemp -d)"
MOUNT_DIR="$(mktemp -d)"
cleanup() {
  hdiutil detach "$MOUNT_DIR" -quiet >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap cleanup EXIT

info "Fetching the latest release..."
DMG_URL="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
  | grep -o 'https://[^"]*Spanorama\.dmg' | head -1 || true)"
[ -n "$DMG_URL" ] || error "No DMG found in the latest release."

info "Downloading $(basename "$DMG_URL")..."
curl -fSL --progress-bar "$DMG_URL" -o "$TMP/Spanorama.dmg"

info "Mounting disk image..."
hdiutil attach "$TMP/Spanorama.dmg" -readonly -nobrowse -mountpoint "$MOUNT_DIR" >/dev/null
[ -d "$MOUNT_DIR/$APP_NAME" ] || error "Spanorama.app not found inside the DMG."

info "Installing to $DEST..."
if [ -d "$DEST/$APP_NAME" ]; then
  info "Removing existing installation..."
  rm -rf "$DEST/$APP_NAME" 2>/dev/null || sudo rm -rf "$DEST/$APP_NAME"
fi
if ! cp -R "$MOUNT_DIR/$APP_NAME" "$DEST/" 2>/dev/null; then
  sudo cp -R "$MOUNT_DIR/$APP_NAME" "$DEST/"
fi

# Belt and braces: never let a stray quarantine flag block first launch.
xattr -dr com.apple.quarantine "$DEST/$APP_NAME" 2>/dev/null || true

info "Installed. Launching Spanorama..."
open "$DEST/$APP_NAME"
