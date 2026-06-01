#!/usr/bin/env bash
# Assembles AgentPet.app from a release build so it runs as a proper menu bar
# app (bundle id, LSUIElement, working notifications). Ad-hoc signed for local
# testing. Notarization + DMG + Homebrew are issue #13.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
APP="$ROOT/build/AgentPet.app"
CONFIG="${1:-release}"

echo "Building ($CONFIG)..."
swift build -c "$CONFIG"
BINDIR="$(swift build -c "$CONFIG" --show-bin-path)"

echo "Assembling $APP ..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BINDIR/agentpet" "$APP/Contents/MacOS/agentpet"
cp "$ROOT/scripts/AppInfo.plist" "$APP/Contents/Info.plist"
[ -f "$ROOT/scripts/AppIcon.icns" ] && cp "$ROOT/scripts/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

# Note: SwiftPM emits an empty AgentPet_AgentPetCore.bundle, but nothing uses
# Bundle.module, so we deliberately do not copy it (it has no Info.plist and
# would break code signing). The app needs no runtime resource bundle.

# Ad-hoc sign for local testing (release.sh re-signs with a Developer ID).
codesign --force --sign - "$APP" || echo "warning: codesign failed (continuing unsigned)"

echo "Done: $APP"
echo "Run with: open \"$APP\"   (or: \"$APP/Contents/MacOS/agentpet\")"
