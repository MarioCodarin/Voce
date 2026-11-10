# Distribution and notarization

Voce ships as a self-contained `.app` with an optional zipped release, DMG and checksums.
The default build is ad-hoc signed, which is enough for local use but triggers Gatekeeper's
"unidentified developer" warning on another Mac. A Developer ID signature and notarization
remove that warning.

## Local build

```bash
./scripts/package-app.sh
open dist/Voce.app
```

## Release artifacts

```bash
./scripts/release.sh
```

This creates:

- `dist/Voce-<version>.zip`
- `dist/Voce-<version>.dmg` (when `hdiutil` is available)
- `dist/SHA256SUMS`

Verify a download with:

```bash
cd dist
shasum -a 256 -c SHA256SUMS
```

Without `CODESIGN_IDENTITY`, the app is ad-hoc signed. No Apple account is required.

## Developer ID and notarization

You need an Apple Developer account, a **Developer ID Application** certificate in the
login keychain, and an app-specific password (or API key) for notarization.

```bash
xcrun notarytool store-credentials voce-notary \
  --apple-id you@example.com \
  --team-id TEAMID \
  --password "app-specific-password"

CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE=voce-notary \
./scripts/release.sh
```

The script signs with the hardened runtime, zips the app, submits it with `notarytool`,
staples the ticket, then rebuilds the final zip/DMG and checksums.

Verify on a clean machine:

```bash
spctl --assess --type execute --verbose=4 /Applications/Voce.app
codesign --verify --deep --strict --verbose=2 /Applications/Voce.app
```

## Versioning

- `Sources/VoceKit/Support/VoceVersion.swift` holds the marketing/build version used by the UI and CLI.
- `Info.plist` must match `CFBundleShortVersionString` / `CFBundleVersion`; `package-app.sh` copies it into the bundle.
- Bump both and add a `CHANGELOG.md` entry before a release.

## Update path

Voce currently has no auto-updater. Users download the new version and run
`./scripts/install.sh` or replace the app in `/Applications`. A future update path should
preserve the Keychain item and `~/.config/voce`, and should verify a signed update before
installing it.

## Data and signing

Changing the signature (ad-hoc rebuild or a new Developer ID) can make macOS ask for Keychain
access again. Choose **Always Allow** once. The key and history stay in the same locations;
signing never moves or uploads them.

## What is not automated

- Apple credentials are never stored in this repository.
- CI builds an app artifact but does not notarize it; notarization requires secrets that are
  intentionally not committed.
- Gatekeeper behaviour on a fresh Mac should be checked before publishing a release.
