#!/bin/bash
# Ships a new stable release: bumps the version, commits, tags, and pushes.
# The tag push triggers CI to build and publish the release; every installed
# copy of Spanorama then shows an update dialog within 6 hours (or on next launch).
#
# Usage: Scripts/release.sh 0.1.1
set -euo pipefail
cd "$(dirname "$0")/.."

if [ $# -ne 1 ] || ! [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "usage: Scripts/release.sh <major.minor.patch>   e.g. Scripts/release.sh 0.1.1" >&2
  exit 2
fi

VERSION="$1"
TAG="v$VERSION"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Resources/Info.plist
git add Resources/Info.plist
git commit -m "Release v$VERSION"
git tag "$TAG"
git push origin main "$TAG"

echo "Pushed $TAG — CI will build and publish the release; installed apps will see the update."
