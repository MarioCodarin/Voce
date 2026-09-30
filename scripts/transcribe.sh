#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/Voce.app/Contents/MacOS/Voce"
if [[ ! -x "$APP" ]]; then
  "$ROOT/scripts/package-app.sh"
fi
exec "$APP" --transcribe "$@"
