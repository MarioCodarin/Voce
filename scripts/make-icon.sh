#!/bin/zsh
# Regenerates Assets/AppIcon.png and Assets/AppIcon.icns from Assets/AppIcon.svg.
# Needs rsvg-convert (brew install librsvg) and iconutil (ships with macOS).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SVG="$ROOT/Assets/AppIcon.svg"
SET="$ROOT/Assets/AppIcon.iconset"

command -v rsvg-convert >/dev/null || { echo "rsvg-convert not found: brew install librsvg" >&2; exit 1; }

rm -rf "$SET"
mkdir -p "$SET"
render() { rsvg-convert -w "$1" -h "$1" "$SVG" -o "$SET/$2"; }
render 16   icon_16x16.png
render 32   icon_16x16@2x.png
render 32   icon_32x32.png
render 64   icon_32x32@2x.png
render 128  icon_128x128.png
render 256  icon_128x128@2x.png
render 256  icon_256x256.png
render 512  icon_256x256@2x.png
render 512  icon_512x512.png
render 1024 icon_512x512@2x.png

cp "$SET/icon_512x512@2x.png" "$ROOT/Assets/AppIcon.png"
iconutil -c icns "$SET" -o "$ROOT/Assets/AppIcon.icns"
rm -rf "$SET"
echo "Wrote Assets/AppIcon.png and Assets/AppIcon.icns"
