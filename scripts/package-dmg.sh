#!/usr/bin/env bash
# Build an unsigned Muskometer Release and package as DMG + zip.
#
# No Apple Developer Program ($99) required.
# Recipients must right-click → Open on first launch (Gatekeeper).
#
# Output:
#   dist/Muskometer-<version>.dmg
#   dist/Muskometer-<version>.zip
#
# For signed + notarized releases (no Gatekeeper prompt), use scripts/release.sh
# with a Developer ID Application certificate — see docs/RELEASE.md.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="Muskometer"
SCHEME="Muskometer"
DIST_DIR="$ROOT/dist"
BUILD_DIR="$ROOT/build"
DERIVED_DATA="$BUILD_DIR/DerivedData"
PRODUCTS="$DERIVED_DATA/Build/Products/Release"

echo "=== Muskometer unsigned package ==="
echo "No code signing — users right-click → Open on first launch."
echo ""

rm -rf "$DERIVED_DATA"
mkdir -p "$DIST_DIR"

echo "=== 1. Release build (unsigned) ==="
xcodebuild \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=NO \
  build \
  | xcpretty 2>/dev/null || xcodebuild \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=NO \
  build

APP="$PRODUCTS/${APP_NAME}.app"
if [[ ! -d "$APP" ]]; then
  echo "ERROR: built app not found at $APP" >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist" 2>/dev/null || echo "unknown")"
BUILD_NUM="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist" 2>/dev/null || echo "unknown")"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
ZIP_NAME="${APP_NAME}-${VERSION}.zip"

echo ""
echo "=== 2. Create DMG + zip ==="
DMG_STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
ditto "$APP" "$DMG_STAGING/${APP_NAME}.app"
ln -sf /Applications "$DMG_STAGING/Applications"

DMG_PATH="$DIST_DIR/$DMG_NAME"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"
rm -f "$DMG_PATH" "$ZIP_PATH"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH" \
  >/dev/null

ditto -c -k --keepParent "$APP" "$ZIP_PATH"

echo ""
echo "=== Package complete ==="
echo "Version: $VERSION ($BUILD_NUM)"
echo "  $DMG_PATH"
echo "  $ZIP_PATH"
echo ""
echo "Upload to GitHub Releases:"
echo "  git tag v${VERSION} && git push origin v${VERSION}"
echo "  gh release create v${VERSION} dist/${DMG_NAME} dist/${ZIP_NAME}"