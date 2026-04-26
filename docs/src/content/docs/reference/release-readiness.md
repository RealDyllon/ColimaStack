---
title: Release Readiness
description: Launch checklist for the ColimaStack app and documentation.
---

This page summarizes the repository release-readiness notes from `docs/release-readiness.md`.

## Launch objective

ColimaStack should be credible as a public macOS developer launch and a serious Colima GUI for local runtime workflows.

The release bar includes:

- profile visibility and lifecycle control
- Docker resource inventory
- Kubernetes resource visibility
- setup diagnostics
- command transparency
- native macOS polish

Current automated verification also covers process environment allowlisting, output caps, process cancellation, profile-name validation, advanced-argument validation, typed profile delete confirmation, resolved tool execution, secret redaction across command outputs/search indexing, and redaction of process failure descriptions.

The current working tree passes the full Xcode test suite and an unsigned Release build with `CODE_SIGNING_ALLOWED=NO`. Signed archive readiness is blocked because no `Developer ID Application` certificate matching team ID `TF835S78NT` with a private key is installed, and the local keychain reports `0 valid identities found`.

The unsigned Release build now uses a populated `AppIcon.appiconset`, excludes the tracked `.icon` bundle from app target membership, and avoids SwiftUI `#Preview` macros in compiled source so local Release builds do not depend on the preview macro plugin.

The repo also includes `docs/audit-checklist.json` for machine-readable audit tracking and `scripts/verify-local.sh` for the local CI-equivalent gate: Debug build, unit/UI tests, unsigned Release build, and Release architecture check.

## Release-candidate checks

Run the local gate:

```sh
scripts/verify-local.sh
```

Set `CLEAN_DERIVED_DATA=1` when you need to force a fresh test DerivedData folder.

Run tests:

```sh
xcodebuild test \
  -project ColimaStack.xcodeproj \
  -scheme ColimaStack \
  -destination 'platform=macOS'
```

Create an archive:

```sh
xcodebuild archive \
  -project ColimaStack.xcodeproj \
  -scheme ColimaStack \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath dist/ColimaStack-1.0-rc.1.xcarchive \
  -derivedDataPath dist/DerivedData \
  -jobs 1
```

Verify signing and architecture:

```sh
codesign --verify --deep --strict --verbose=2 \
  dist/ColimaStack-1.0-rc.1.xcarchive/Products/Applications/ColimaStack.app

lipo -archs \
  dist/ColimaStack-1.0-rc.1.xcarchive/Products/Applications/ColimaStack.app/Contents/MacOS/ColimaStack
```

## Manual checks before public launch

- Smoke-test a default profile and named profile.
- Validate Docker context mismatch handling.
- Validate missing dependency messaging.
- Validate real editor handoff for configuration editing.
- Close or explicitly descope the Deferred/Partial states in `design/mockups/screen_inventory.md`.
- Install a valid Developer ID Application identity for team `TF835S78NT`.
- Build, sign, notarize, staple, and install a Developer ID distribution artifact on a clean macOS account.

The latest local RC artifact is not public-distributable audit evidence for the current working tree until a new Developer ID archive is signed, notarized, stapled, and installed on a clean macOS account.
