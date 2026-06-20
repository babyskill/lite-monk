#!/usr/bin/env bash
# Assembles, signs, and packages LiteMonk for the Mac App Store.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/LiteMonk-AppStore.app"
PKG="$BUILD_DIR/LiteMonk.pkg"
IDENTITY="Apple Distribution: Kien Le (Q7N9KCCNW6)"
INSTALLER_IDENTITY="3rd Party Mac Developer Installer: Kien Le (Q7N9KCCNW6)"
PROVISION_PROFILE="$ROOT/AppStore_com.litemonk.app.provisionprofile"

echo "==> Cleaning previous App Store build..."
rm -rf "$APP" "$PKG"
mkdir -p "$BUILD_DIR"

echo "==> Compiling for App Store (universal arm64 + x86_64, excluding Sparkle)..."
swift build -c release --arch arm64 --arch x86_64 -Xswiftc -DAPPSTORE
BINDIR="$(swift build -c release --arch arm64 --arch x86_64 -Xswiftc -DAPPSTORE --show-bin-path)"

echo "==> Assembling $APP..."
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BINDIR/litemonk" "$APP/Contents/MacOS/litemonk"
cp "$ROOT/scripts/AppInfo.plist" "$APP/Contents/Info.plist"

# Clean up Sparkle settings in Info.plist for App Store compliance
echo "==> Modifying Info.plist for App Store compliance..."
/usr/libexec/PlistBuddy -c "Delete :SUFeedURL" "$APP/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :SUPublicEDKey" "$APP/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :SUEnableAutomaticChecks" "$APP/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.litemonk.app" "$APP/Contents/Info.plist"

# Set CFBundleVersion to match CFBundleShortVersionString
SHORT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $SHORT_VERSION" "$APP/Contents/Info.plist"

[ -f "$ROOT/scripts/AppIcon.icns" ] && cp "$ROOT/scripts/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

# Copy Localizations
if [ -d "$ROOT/Localizations" ]; then
    for lproj in "$ROOT/Localizations"/*.lproj; do
        [ -d "$lproj" ] && cp -R "$lproj" "$APP/Contents/Resources/"
    done
fi

# Copy process resource bundle
RESOURCE_BUNDLE="$BINDIR/LiteMonk_litemonk.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "$APP/Contents/Resources/"
fi

# Embed the provisioning profile (required for App Store)
echo "==> Embedding provisioning profile..."
cp "$PROVISION_PROFILE" "$APP/Contents/embedded.provisionprofile"

# Sign nested bundles first
echo "==> Signing resources and nested bundles..."
if [ -d "$APP/Contents/Resources/LiteMonk_litemonk.bundle" ]; then
    codesign --force --timestamp --options runtime --sign "$IDENTITY" "$APP/Contents/Resources/LiteMonk_litemonk.bundle"
fi

# Sign main executable and app bundle with Sandboxing entitlements
echo "==> Signing application with entitlements..."
codesign --force --timestamp --options runtime --entitlements scripts/LiteMonk.entitlements --sign "$IDENTITY" "$APP/Contents/MacOS/litemonk"
codesign --force --timestamp --options runtime --entitlements scripts/LiteMonk.entitlements --sign "$IDENTITY" "$APP"

# Verify signature
echo "==> Verifying signature..."
codesign --verify --deep --strict --verbose=2 "$APP"

# Package into .pkg using productbuild
echo "==> Creating installer package (.pkg)..."
productbuild --component "$APP" /Applications --sign "$INSTALLER_IDENTITY" "$PKG"

echo "==> Verifying installer package signature..."
pkgutil --check-signature "$PKG"

echo "==> App Store Package successfully generated at: $PKG"
