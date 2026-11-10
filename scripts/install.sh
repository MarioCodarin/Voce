#!/bin/zsh
# Build and copy Voce.app to /Applications, replacing the installed copy.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="/Applications/Voce.app"

"$ROOT/scripts/package-app.sh"

# Quit a running copy before replacing it. Unsaved work is lost only if it was not archived;
# the app asks before discarding, so this is the same action as Cmd+Q.
if pgrep -x Voce >/dev/null 2>&1; then
  osascript -e 'tell application "Voce" to quit' >/dev/null 2>&1 || true
  sleep 1
  pkill -x Voce >/dev/null 2>&1 || true
fi

if [[ ! -d "$ROOT/dist/Voce.app" ]]; then
  echo "build failed: dist/Voce.app is missing" >&2
  exit 1
fi

rm -rf "$DEST"
ditto "$ROOT/dist/Voce.app" "$DEST"
xattr -dr com.apple.quarantine "$DEST" >/dev/null 2>&1 || true

echo "Installed $DEST"
open "$DEST"
