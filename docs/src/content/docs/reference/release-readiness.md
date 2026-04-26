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

## Release-candidate checks

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
- Build, sign, notarize, staple, and install a Developer ID distribution artifact on a clean macOS account.
