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
BIN_DIR="$(dirname "$BIN")"
for bundle in "$BIN_DIR"/*.bundle; do
  [ -d "$bundle" ] || continue
  cp -R "$bundle" "$APP/Contents/Resources/"
done
chmod +x "$APP/Contents/MacOS/Voce"
codesign -s - --force "$APP" >/dev/null

echo "Built $APP"
