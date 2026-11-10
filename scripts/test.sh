#!/bin/zsh
# Run the test suite. With only the Command Line Tools selected, Swift Testing needs
# explicit framework and macro-plugin paths; with Xcode selected, plain `swift test` works.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if xcode-select -p 2>/dev/null | grep -q "CommandLineTools"; then
  F="/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
  L="/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
  exec swift test --build-system native \
    -Xswiftc -F"$F" -Xlinker -F"$F" \
    -Xlinker -rpath -Xlinker "$F" -Xlinker -rpath -Xlinker "$L" \
    -Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing \
    "$@"
fi

exec swift test "$@"
