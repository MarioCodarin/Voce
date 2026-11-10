#!/bin/zsh
set -euo pipefail
setopt NULL_GLOB
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

swift build -c release --product Voce

BIN="$(swift build -c release --show-bin-path)/Voce"
APP="$ROOT/dist/Voce.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Voce"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$ROOT/Assets/AppIcon.png" "$APP/Contents/Resources/AppIcon.png"
cp "$ROOT/Sources/VoceKit/Resources/glossary.txt" "$APP/Contents/Resources/glossary.txt"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# SwiftPM resource bundles (the bundled glossary lives in one of these).
BIN_DIR="$(dirname "$BIN")"
for bundle in "$BIN_DIR"/*.bundle; do
  [ -d "$bundle" ] || continue
  cp -R "$bundle" "$APP/Contents/Resources/"
done

chmod +x "$APP/Contents/MacOS/Voce"
codesign --force --sign - "$APP" >/dev/null

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP/Contents/Info.plist")
codesign --verify --deep --strict "$APP" >/dev/null

echo "Built $APP — Voce $VERSION ($BUILD)"
