#!/usr/bin/env bash
# Build a signed, distributable Muskometer release (DMG + zip).
#
# Required for signing:
#   APPLE_TEAM_ID          10-character Apple Developer Team ID
#
# Optional:
#   CODESIGN_IDENTITY      Default: "Developer ID Application"
#   NOTARY_PROFILE         Keychain profile for xcrun notarytool (recommended)
#   APPLE_API_KEY_ID       App Store Connect API key ID (alternative notarization)
#   APPLE_API_KEY_ISSUER_ID
#   APPLE_API_KEY_PATH     Path to AuthKey_*.p8 file
#   APPLE_ID               Apple ID email (legacy notarization)
#   APPLE_APP_SPECIFIC_PASSWORD
#   NOTARIZE=0             Force-skip notarization even if credentials are set
#   SKIP_NOTARIZE=1        Alias for NOTARIZE=0
#
# See docs/RELEASE.md for one-time Apple setup and GitHub Release upload steps.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="Muskometer"
SCHEME="Muskometer"
DIST_DIR="$ROOT/dist"
BUILD_DIR="$ROOT/build"
DERIVED_DATA="$BUILD_DIR/DerivedData"
ARCHIVE_PATH="$BUILD_DIR/${APP_NAME}.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
EXPORT_PLIST="$BUILD_DIR/ExportOptions.plist"

CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-Developer ID Application}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-${DEVELOPMENT_TEAM:-}}"

# Load team ID from local xcconfig if env not set.
if [[ -z "$APPLE_TEAM_ID" && -f Config/Release.xcconfig ]]; then
  APPLE_TEAM_ID="$(grep -E '^DEVELOPMENT_TEAM\s*=' Config/Release.xcconfig | head -1 | sed 's/.*=\s*//' | tr -d '[:space:]')" || true
fi

if [[ -z "$APPLE_TEAM_ID" ]]; then
  cat >&2 <<'EOF'
ERROR: APPLE_TEAM_ID is not set.

Set your 10-character Team ID before running a release build:
  export APPLE_TEAM_ID=XXXXXXXXXX

Or copy Config/Release.xcconfig.example to Config/Release.xcconfig and fill in DEVELOPMENT_TEAM.

Find your Team ID: https://developer.apple.com/account → Membership details
EOF
  exit 1
fi

if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
  cat >&2 <<'EOF'
WARN: No "Developer ID Application" certificate found in the login keychain.
Create one at https://developer.apple.com/account/resources/certificates/list
(Developer ID Application → download → double-click to install).
EOF
fi

echo "=== Muskometer release build ==="
echo "Team ID: $APPLE_TEAM_ID"
echo "Sign identity: $CODESIGN_IDENTITY"
echo ""

rm -rf "$DERIVED_DATA" "$ARCHIVE_PATH" "$EXPORT_DIR"
mkdir -p "$DIST_DIR"

XCODE_ARGS=(
  -scheme "$SCHEME"
  -configuration Release
  -derivedDataPath "$DERIVED_DATA"
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID"
  CODE_SIGN_IDENTITY="$CODESIGN_IDENTITY"
  CODE_SIGN_STYLE=Automatic
)

if [[ -f Config/Release.xcconfig ]]; then
  XCODE_ARGS+=(-xcconfig Config/Release.xcconfig)
fi

echo "=== 1. Archive (Release) ==="
xcodebuild archive \
  "${XCODE_ARGS[@]}" \
  -archivePath "$ARCHIVE_PATH" \
  | xcpretty 2>/dev/null || xcodebuild archive \
  "${XCODE_ARGS[@]}" \
  -archivePath "$ARCHIVE_PATH"

echo ""
echo "=== 2. Export Developer ID app ==="
cat >"$EXPORT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>teamID</key>
  <string>${APPLE_TEAM_ID}</string>
  <key>signingStyle</key>
  <string>automatic</string>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_PLIST" \
  | xcpretty 2>/dev/null || xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_PLIST"

APP="$EXPORT_DIR/${APP_NAME}.app"
if [[ ! -d "$APP" ]]; then
  echo "ERROR: exported app not found at $APP" >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist" 2>/dev/null || echo "unknown")"
BUILD_NUM="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist" 2>/dev/null || echo "unknown")"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
ZIP_NAME="${APP_NAME}-${VERSION}.zip"

echo ""
echo "=== 3. Verify code signature ==="
codesign --verify --deep --strict --verbose=2 "$APP"
spctl -a -t exec -vv "$APP" 2>&1 || echo "NOTE: spctl will pass after notarization and stapling."

echo ""
echo "=== 4. Create distribution artifacts ==="
DMG_STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
ditto "$APP" "$DMG_STAGING/${APP_NAME}.app"
ln -sf /Applications "$DMG_STAGING/Applications"

DMG_PATH="$DIST_DIR/$DMG_NAME"
rm -f "$DMG_PATH"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH" \
  >/dev/null

ZIP_PATH="$DIST_DIR/$ZIP_NAME"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP" "$ZIP_PATH"

echo "Created: $DMG_PATH"
echo "Created: $ZIP_PATH"

notarize_artifact() {
  local artifact="$1"
  echo ""
  echo "=== 5. Notarize $(basename "$artifact") ==="

  local submit_args=(submit "$artifact" --wait)

  if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    submit_args+=(--keychain-profile "$NOTARY_PROFILE")
  elif [[ -n "${APPLE_API_KEY_ID:-}" && -n "${APPLE_API_KEY_ISSUER_ID:-}" && -n "${APPLE_API_KEY_PATH:-}" ]]; then
    submit_args+=(--key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_KEY_ISSUER_ID" --key "$APPLE_API_KEY_PATH")
  elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
    submit_args+=(--apple-id "$APPLE_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD" --team-id "$APPLE_TEAM_ID")
  else
    echo "SKIP: no notarization credentials (set NOTARY_PROFILE or API key env vars)."
    return 0
  fi

  xcrun notarytool "${submit_args[@]}"
  xcrun stapler staple "$artifact"
  echo "Stapled notarization ticket to $(basename "$artifact")"
}

if [[ "${NOTARIZE:-1}" != "0" && "${SKIP_NOTARIZE:-0}" != "1" ]]; then
  if [[ -n "${NOTARY_PROFILE:-}" \
    || ( -n "${APPLE_API_KEY_ID:-}" && -n "${APPLE_API_KEY_ISSUER_ID:-}" && -n "${APPLE_API_KEY_PATH:-}" ) \
    || ( -n "${APPLE_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ) ]]; then
    notarize_artifact "$DMG_PATH"
    # Re-staple app and refresh zip so offline Gatekeeper checks work on the zip too.
    xcrun stapler staple "$APP"
    rm -f "$ZIP_PATH"
    ditto -c -k --keepParent "$APP" "$ZIP_PATH"
  else
    echo ""
    echo "=== 5. Notarization skipped ==="
    echo "No NOTARY_PROFILE or Apple API credentials in environment."
    echo "Users may need to right-click → Open on first launch until you notarize."
  fi
else
  echo ""
  echo "=== 5. Notarization skipped (NOTARIZE=0) ==="
fi

echo ""
echo "=== Release complete ==="
echo "Version: $VERSION ($BUILD_NUM)"
echo "Artifacts:"
echo "  $DMG_PATH"
echo "  $ZIP_PATH"
echo ""
echo "Next steps — GitHub Release:"
echo "  1. Tag the release:  git tag v${VERSION} && git push origin v${VERSION}"
echo "  2. Open: https://github.com/jlgolson/muskometer/releases/new?tag=v${VERSION}"
echo "  3. Title: Muskometer ${VERSION}"
echo "  4. Attach: dist/${DMG_NAME} (and optionally dist/${ZIP_NAME})"
echo "  5. Publish — README install link will pick up the latest release automatically."