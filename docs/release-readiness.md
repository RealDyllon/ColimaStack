# Release Readiness Notes

This checklist is scoped to launch-critical ColimaStack behavior and the command API documented in [docs/colima-command-api-reference.md](/Users/dyllon/Developer/colima-stack/docs/colima-command-api-reference.md).

## Launch objective

ColimaStack is the macOS GUI for Colima. The product bar for this release is a public, developer-facing launch that can stand up to Hacker News, Product Hunt, Substack/newsletter coverage, and direct comparison with OrbStack and Docker Desktop for local Colima workflows.

The app should make developers comfortable moving their day-to-day container runtime management to ColimaStack by providing:

- fast profile visibility and lifecycle control
- live Docker resource inventory for the active Colima context
- Kubernetes cluster, workload, and service visibility for Colima profiles
- dependable setup diagnostics and recovery paths
- command transparency through progress, history, and raw terminal output
- conservative native macOS UI that feels production-grade instead of demo-like

## Scope used for this checklist

This is inferred from the current mockup inventory in [design/mockups/screen_inventory.md](/Users/dyllon/Developer/colima-stack/design/mockups/screen_inventory.md):

- first-run dependency/setup flows
- profile lifecycle operations
- Docker containers, images, volumes, networks, and runtime metrics
- command progress, logs, and failure recovery
- Kubernetes cluster, workload, service visibility, and toggles
- settings-backed profile configuration
- SSH/config document access

## Backend and domain readiness

- `colima` missing path produces a dedicated user-facing failure path.
- Profile list and status parsing handle JSON and plain-text forms.
- “colima is not running” is normalized to a stopped state instead of an opaque failure.
- Daemon logs are read from disk without requiring a shell call.
- Start command construction is covered with fake process execution.
- Start passes through VZ Rosetta and nested virtualization settings to Colima CLI flags.
- Delete uses Colima's non-interactive `--force` flag after app-level confirmation to avoid hung release builds.
- Docker diagnostics probe the expected Colima Docker context explicitly instead of depending on the active Docker context.
- Stop, restart, delete, update, and Kubernetes subcommands are covered with fake process execution.
- Template/config/SSH document access is covered without real Colima dependencies.
- Docker and Kubernetes inventory screens are backed by command-runner services instead of static placeholders.
- Stored profile mounts are hydrated back into the profile detail screens from Colima configuration files.
- UI tests launch with deterministic mock data and cover primary navigation, light mode, and dark mode launch paths.

## Release candidate procedure

Use a fresh derived-data folder for reproducible RC builds:

```sh
xcodebuild test \
  -project ColimaStack.xcodeproj \
  -scheme ColimaStack \
  -destination 'platform=macOS'

xcodebuild archive \
  -project ColimaStack.xcodeproj \
  -scheme ColimaStack \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath dist/ColimaStack-1.0-rc.1.xcarchive \
  -derivedDataPath dist/DerivedData \
  -jobs 1

ditto -c -k --keepParent \
  dist/ColimaStack-1.0-rc.1.xcarchive/Products/Applications/ColimaStack.app \
  dist/ColimaStack-1.0-rc.1-local.zip

shasum -a 256 dist/ColimaStack-1.0-rc.1-local.zip \
  > dist/ColimaStack-1.0-rc.1-local.zip.sha256
```

Validate the packaged app:

```sh
codesign --verify --deep --strict --verbose=2 \
  dist/ColimaStack-1.0-rc.1.xcarchive/Products/Applications/ColimaStack.app

lipo -archs \
  dist/ColimaStack-1.0-rc.1.xcarchive/Products/Applications/ColimaStack.app/Contents/MacOS/ColimaStack

spctl --assess --type execute --verbose=4 \
  dist/ColimaStack-1.0-rc.1.xcarchive/Products/Applications/ColimaStack.app
```

The local RC archive may pass `codesign --verify` while failing `spctl` if it is ad-hoc or Apple Development signed. A public release requires Developer ID Application signing and notarization:

```sh
xcrun notarytool submit dist/ColimaStack-1.0-rc.1.zip --keychain-profile <profile> --wait
xcrun stapler staple dist/ColimaStack-1.0-rc.1.xcarchive/Products/Applications/ColimaStack.app
spctl --assess --type execute --verbose=4 dist/ColimaStack-1.0-rc.1.xcarchive/Products/Applications/ColimaStack.app
```

## Latest local RC result

Generated on April 26, 2026:

- Archive: `dist/ColimaStack-1.0-rc.1.xcarchive`
- Zip: `dist/ColimaStack-1.0-rc.1-local.zip`
- SHA-256: `03a5a091b31edb5350ab6cf20f17aef0598ec34f0137738f5519757f01f7adfc`
- Bundle ID: `io.dyllon.ColimaStack`
- Version: `1.0 (1)`
- Architectures: `x86_64 arm64`
- App category: `public.app-category.developer-tools`
- `xcodebuild test -project ColimaStack.xcodeproj -scheme ColimaStack -destination 'platform=macOS'`: passed
- `xcodebuild archive ... -archivePath dist/ColimaStack-1.0-rc.1.xcarchive`: passed
- `codesign --verify --deep --strict`: passed
- `spctl --assess --type execute`: rejected because the local archive is ad-hoc signed

This is a local release-candidate artifact, not a public distributable build. The machine used for this RC only had an Apple Development signing identity and no Developer ID Application identity, so Developer ID signing and notarization could not be completed.

## Manual checks still required before public launch

- Verify command spelling against the exact Colima release being targeted.
- Smoke-test a default profile and one named profile on macOS.
- Validate Docker context mismatch handling against a live non-Colima context.
- Validate permissions/setup messaging with missing `colima`, `docker`, and `kubectl`.
- Validate configuration editing with a real editor handoff.
- Build, sign, notarize, staple, and install the Developer ID distribution artifact on a clean macOS account.

## Known release risks

- The app relies on Colima, Docker, and kubectl CLI contracts; final manual smoke testing must use the exact Colima version promoted in launch materials.
- The backend reads some Colima files directly from `$COLIMA_HOME`; that path contract should be checked against upgrade and multi-profile scenarios.
- No tests in this slice execute real Colima, Docker, or kubectl binaries by design, so a final manual smoke pass remains necessary.
- Developer ID signing and notarization cannot be completed on a machine that only has an Apple Development signing identity.
