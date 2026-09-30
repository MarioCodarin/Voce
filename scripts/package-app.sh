#!/bin/zsh
set -euo pipefail
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
BIN_DIR="$(dirname "$BIN")"
if [ -d "$BIN_DIR/Voce_Voce.bundle" ]; then
  cp -R "$BIN_DIR/Voce_Voce.bundle" "$APP/Contents/Resources/"
fi
chmod +x "$APP/Contents/MacOS/Voce"
codesign -s - --force "$APP" >/dev/null

echo "Built $APP"
