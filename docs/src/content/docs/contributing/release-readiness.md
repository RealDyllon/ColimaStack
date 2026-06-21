---
title: Release Readiness
description: Internal maintainer release, signing, notarization, and smoke-test checklist.
---

This is maintainer documentation. It is not public install guidance.

## Current state

- The app target is `ColimaStack` and the scheme is `ColimaStack`.
- The Xcode deployment target is macOS 14.0.
- CI builds and packages unsigned app zip artifacts with signing disabled.
- The repository does not show Sparkle or another auto-update implementation.
- A public Developer ID signed, notarized, stapled, and clean-machine verified app artifact is not documented as available.

## Local verification

```sh
xcodebuild test \
  -project ColimaStack.xcodeproj \
  -scheme ColimaStack \
  -configuration Debug \
  -destination 'platform=macOS' \
  -skip-testing:ColimaStackUITests \
  CODE_SIGNING_ALLOWED=NO
```

```sh
xcodebuild build \
  -project ColimaStack.xcodeproj \
  -scheme ColimaStack \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=""
```

The repository also includes `scripts/verify-local.sh` for local build/test/release-build checks.

## Public artifact checklist

Before public user docs can say to download a signed release:

- Build a Release archive from the current working tree.
- Sign with a valid Developer ID Application identity.
- Notarize with Apple.
- Staple the notarization ticket.
- Verify with `codesign` and `spctl`.
- Install on a clean macOS account.
- Smoke-test first launch, Diagnostics, profile discovery, profile start/stop, Docker inventory, Kubernetes-disabled state, and menu bar actions.
- Publish the artifact and checksum through a documented public release channel.

Until this is complete, user docs should say to build from source or clearly label unsigned artifacts.
