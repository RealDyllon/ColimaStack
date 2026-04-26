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
- Delete requires profile-specific typed confirmation before the app invokes Colima's non-interactive `--force` delete.
- Child processes inherit only an allowlisted environment, captured output is capped, and task cancellation terminates live spawned processes.
- Profile names from user input, environment fallback, and Colima list output are validated before path, environment, or process use.
- Advanced profile arguments reject managed flags that would bypass structured UI controls.
- Docker diagnostics probe the expected Colima Docker context explicitly instead of depending on the active Docker context.
- Stop, restart, delete, update, and Kubernetes subcommands are covered with fake process execution.
- Template/config/SSH document access is covered without real Colima dependencies.
- Docker and Kubernetes inventory screens are backed by command-runner services instead of static placeholders.
- Stored profile mounts are hydrated back into the profile detail screens from Colima configuration files.
- UI tests launch with deterministic mock data and cover primary navigation, typed delete confirmation, light mode, and dark mode launch paths.

## Release candidate procedure

For the local CI-equivalent gate, run:

```sh
scripts/verify-local.sh
```

That script builds Debug, runs the unit/UI test suite, builds an unsigned Release app from a fresh Release DerivedData folder, and prints the Release executable architectures. Set `CLEAN_DERIVED_DATA=1` to force a fresh test DerivedData folder as well.

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

## Historical local RC result

An earlier local RC was generated on April 26, 2026 at `dist/ColimaStack-1.0-rc.1.xcarchive`, but it is not audit evidence for the current working tree. It was produced before the latest process hardening, profile validation, typed delete confirmation, redaction, and app-icon fixes, and it was not Developer ID signed, notarized, stapled, or clean-account installed.

Do not use that historical artifact for public distribution or final audit sign-off. Current release evidence must come from a newly built Developer ID archive for this working tree.

## Current working tree verification

Verified on April 26, 2026:

- `xcodebuild test -project ColimaStack.xcodeproj -scheme ColimaStack -destination platform=macOS -derivedDataPath DerivedData`: passed
- Result bundle: `DerivedData/Logs/Test/Test-ColimaStack-2026.04.26_18-18-32-+0800.xcresult`
- Latest post-audit test command passed with unsigned local signing: `xcodebuild test -project ColimaStack.xcodeproj -scheme ColimaStack -destination platform=macOS -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO`
- Latest post-audit result bundle: `DerivedData/Logs/Test/Test-ColimaStack-2026.04.26_18-54-50-+0800.xcresult`
- Coverage added for process environment allowlisting, stdin-after-launch, output caps, process cancellation, profile-name validation, advanced-argument validation, typed delete confirmation, resolved tool execution, secret redaction across command outputs/search indexing, and redaction of process failure descriptions.
- Machine-readable audit tracker: `docs/audit-checklist.json`.
- CI-equivalent local verification script: `scripts/verify-local.sh`.
- Unsigned Release build command passed: `xcodebuild build -project ColimaStack.xcodeproj -scheme ColimaStack -configuration Release -destination 'generic/platform=macOS' -derivedDataPath /tmp/ColimaStackVerify-Release-AppIcon -jobs 1 CODE_SIGNING_ALLOWED=NO`
- Unsigned app path: `/tmp/ColimaStackVerify-Release-AppIcon/Build/Products/Release/ColimaStack.app`
- `lipo -archs` on the unsigned Release executable reported `x86_64 arm64`.
- App icon release portability fixed: the target now uses populated `Assets.xcassets/AppIcon.appiconset`; the Xcode `.icon` bundle is excluded from target membership.
- SwiftUI previews now use `PreviewProvider` instead of the `#Preview` macro so Release/test builds do not depend on the preview macro plugin.
- In the Codex seatbelt sandbox, `scripts/verify-local.sh` can still be interrupted by Xcode's distributed test notification `Trace/BPT trap`; the same test command passed when run directly, and the Release build command passed separately.
- Signed archive command failed: `xcodebuild archive -project ColimaStack.xcodeproj -scheme ColimaStack -configuration Release -destination 'generic/platform=macOS' -archivePath /tmp/ColimaStack-current-20260426-1821.xcarchive -derivedDataPath /tmp/ColimaStackReleaseDerivedData-20260426-1821 -jobs 1`
- Archive failure: no `Developer ID Application` signing certificate matching team ID `TF835S78NT` with a private key was found.
- `security find-identity -v -p codesigning` reported `0 valid identities found`.
- `codesign --verify --deep --strict` on the unsigned Release app failed with `code object is not signed at all`.
- `spctl --assess --type execute` on the unsigned Release app failed in the Code Signing subsystem.
- No current signed Release archive, Developer ID signing proof, notarization, stapling, clean-account install, or live Colima/Docker/Kubernetes smoke test has been produced for this working tree.

## Mockup reconciliation

The 57-state inventory in [design/mockups/screen_inventory.md](/Users/dyllon/Developer/colima-stack/design/mockups/screen_inventory.md) is now reconciled against implementation. Current blockers before claiming full design coverage:

- Deferred: first-run welcome, install/locate dependency flow, per-container delete/inspect/logs/files, container start/restart confirmations, and compact-width behavior below the current 900 point minimum.
- Partial: slow CLI call treatment, bad Docker context, Kubernetes disconnect, permission/path remediation, row overflow edge cases, dark-mode screenshot evidence, component-state evidence, design-token evidence, and VoiceOver keyboard audit.
- Implemented and verified: profile lifecycle basics, typed profile delete confirmation, search/no-results states, profile editor validation, Docker/Kubernetes inventory screens, settings tabs, command history, loading/refresh states, and missing dependency states.

## Manual checks still required before public launch

- Verify command spelling against the exact Colima release being targeted.
- Smoke-test a default profile and one named profile on macOS.
- Validate Docker context mismatch handling against a live non-Colima context.
- Validate permissions/setup messaging with missing `colima`, `docker`, and `kubectl`.
- Validate configuration editing with a real editor handoff.
- Close or explicitly descope every Deferred/Partial state in `design/mockups/screen_inventory.md`.
- Install a valid Developer ID Application identity for team `TF835S78NT`.
- Build, sign, notarize, staple, and install the Developer ID distribution artifact on a clean macOS account.

## Known release risks

- The app relies on Colima, Docker, and kubectl CLI contracts; final manual smoke testing must use the exact Colima version promoted in launch materials.
- The backend reads some Colima files directly from `$COLIMA_HOME`; that path contract should be checked against upgrade and multi-profile scenarios.
- No tests in this slice execute real Colima, Docker, or kubectl binaries by design, so a final manual smoke pass remains necessary.
- Developer ID signing and notarization cannot be completed until this machine has a valid Developer ID Application identity.
