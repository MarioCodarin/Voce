#!/usr/bin/env python3
"""Checks that every static English UI string has ES/FR/DE/PT translations.

The dynamic strings (counts, file names, statuses) are covered by `Copy.t6` and the
VoceKit language switches; this guards the large keyed catalog.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COPY = ROOT / "Sources/Voce/Localization/Copy.swift"
TRANSLATIONS = ROOT / "Sources/Voce/Localization/Translations.swift"

T_CALL = re.compile(r't\(\s*("(?:[^"\\]|\\.)*")\s*,\s*("(?:[^"\\]|\\.)*")\s*\)', re.S)
DICT_LINE = re.compile(r'^\s*("(?:[^"\\]|\\.)*"):\s*("(?:[^"\\]|\\.)*"),?\s*$')

def decode(literal: str) -> str:
    try:
        return json.loads(literal)
    except json.JSONDecodeError as error:
        raise SystemExit(f"cannot decode Swift literal {literal}: {error}") from error

def main() -> int:
    copy = COPY.read_text(encoding="utf-8")
    static: set[str] = set()
    for italian, english in T_CALL.findall(copy):
        if "\\(" in english:
            continue  # dynamic; handled by t6 / VoceKit
        static.add(decode(english))

    text = TRANSLATIONS.read_text(encoding="utf-8")
    blocks = re.findall(
        r'private static let (spanish|french|german|portuguese): \[String: String\] = \[(.*?)\n\]',
        text,
        re.S,
    )
    if len(blocks) != 4:
        print(f"expected 4 language dictionaries, found {len(blocks)}", file=sys.stderr)
        return 1

    failures = 0
    for name, body in blocks:
        table: dict[str, str] = {}
        for line in body.splitlines():
            match = DICT_LINE.match(line)
            if not match:
                continue
            key, value = decode(match.group(1)), decode(match.group(2))
            if key in table:
                print(f"{name}: duplicate key {key!r}", file=sys.stderr)
                failures += 1
            if not value.strip():
                print(f"{name}: empty translation for {key!r}", file=sys.stderr)
                failures += 1
            table[key] = value
        missing = sorted(static - set(table))
        extra = sorted(set(table) - static)
        if missing:
            print(f"{name}: {len(missing)} missing translation(s)", file=sys.stderr)
            for key in missing:
                print(f"  - {key}", file=sys.stderr)
            failures += len(missing)
        if extra:
            print(f"{name}: {len(extra)} stale translation(s)", file=sys.stderr)
            for key in extra:
                print(f"  + {key}", file=sys.stderr)
            failures += len(extra)
        print(f"{name}: {len(table)} strings")

    print(f"static English strings: {len(static)}")
    if failures:
        print(f"localization check failed with {failures} issue(s)", file=sys.stderr)
        return 1
    print("localization check passed")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
