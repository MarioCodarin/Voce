#!/bin/zsh
# Builds a release app, optional Developer ID signature/notarization, zip, DMG and checksums.
#
# Ad-hoc (default):
#   ./scripts/release.sh
#
# Developer ID + notarization:
#   CODESIGN_IDENTITY="Developer ID Application: Name (TEAMID)" \
#   NOTARY_PROFILE=voce-notary ./scripts/release.sh
#
# Create the notary profile once with:
#   xcrun notarytool store-credentials voce-notary \
#     --apple-id you@example.com --team-id TEAMID --password app-specific-password
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

./scripts/package-app.sh

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" dist/Voce.app/Contents/Info.plist)
ZIP="$ROOT/dist/Voce-$VERSION.zip"
DMG="$ROOT/dist/Voce-$VERSION.dmg"
SUMS="$ROOT/dist/SHA256SUMS"
rm -f "$ZIP" "$DMG" "$SUMS"

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  if [[ "${CODESIGN_IDENTITY:--}" == "-" ]]; then
    echo "notarization needs a Developer ID identity in CODESIGN_IDENTITY" >&2
    exit 1
  fi
  TMP_ZIP="$ROOT/dist/.notarize.zip"
  ditto -c -k --sequesterRsrc --keepParent dist/Voce.app "$TMP_ZIP"
  echo "Submitting to Apple notary service…"
  xcrun notarytool submit "$TMP_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple dist/Voce.app
  rm -f "$TMP_ZIP"
  echo "Notarization ticket stapled"
fi

ditto -c -k --sequesterRsrc --keepParent dist/Voce.app "$ZIP"
if command -v hdiutil >/dev/null; then
  hdiutil create -volname "Voce $VERSION" -srcfolder dist/Voce.app -ov -format UDZO "$DMG" >/dev/null
fi

(
  cd "$ROOT/dist"
  shasum -a 256 "Voce-$VERSION.zip"
  if [[ -f "Voce-$VERSION.dmg" ]]; then shasum -a 256 "Voce-$VERSION.dmg"; fi
) > "$SUMS"

echo "Release $VERSION"
ls -lh "$ZIP" "$DMG" "$SUMS" 2>/dev/null || ls -lh "$ZIP" "$SUMS"
