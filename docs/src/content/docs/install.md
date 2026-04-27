---
title: Install
description: Build ColimaStack from source and install the command-line tools it controls.
---

ColimaStack is a macOS app that controls local tools on your machine. It does not install or replace Colima, Docker, or kubectl.

## Current acquisition path

Build from source is the reliable path documented by this repository today. The GitHub Actions release workflow can package unsigned app zip artifacts, but the repository does not show a public Developer ID distribution flow. Do not treat workflow artifacts as notarized production downloads.

## Requirements

- macOS 14 or later.
- Xcode for building the app.
- Colima and Docker CLI for the default Docker workflow.
- `kubectl` only for Kubernetes workflows.
- Lima/`limactl`; Homebrew normally installs Lima with Colima, and diagnostics check it separately.

See [Compatibility](/compatibility/) for architecture, runtime, and optional feature notes.

## Install dependencies

Existing Colima user:

```sh
brew install docker
colima version
docker version
```

New Colima setup:

```sh
brew install colima docker
colima start
docker context use colima
docker ps
```

Install Kubernetes tooling only if you use Kubernetes:

```sh
brew install kubectl
kubectl version --client
```

If Diagnostics reports `limactl` missing, install Lima explicitly:

```sh
brew install lima
```

## Build from source

From the repository root:

```sh
open ColimaStack.xcodeproj
```

In Xcode, select the `ColimaStack` scheme and run it.

Terminal build:

```sh
xcodebuild -project ColimaStack.xcodeproj -scheme ColimaStack build
```

Release-style unsigned local build:

```sh
xcodebuild build \
  -project ColimaStack.xcodeproj \
  -scheme ColimaStack \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

The CI workflow uses the same project and scheme, builds with signing disabled, and zips `ColimaStack.app`.

## Open the app

After building from Xcode, run the app from Xcode or open the built `ColimaStack.app` from the Xcode products folder. On first launch, ColimaStack checks `colima`, `docker`, `kubectl`, and `limactl`, then loads profiles with `colima list --json`.

If macOS shows a local-build security prompt, use the normal macOS flow for apps you built locally. The repo does not currently document a notarized public app bundle.

## Verify after launch

1. Open `Diagnostics` and confirm `colima` and `docker` are available.
2. Open `Profiles` and select or create a profile.
3. Start the profile if it is stopped.
4. Open `Containers` and run the [Quick Start](/quick-start/) sample container if the list is empty.

## Troubleshooting missing tools

- `colima` missing: install Colima and make sure it is in `PATH`.
- `docker` missing: install Docker CLI and restart the app.
- `kubectl` missing: install it only if you need Kubernetes views.
- `limactl` missing: install Lima if Diagnostics needs deeper runtime checks.
- Docker unavailable: start the selected profile and verify the Docker context shown in `Overview`.

For data handling and local command execution details, see [Security & Privacy](/security-privacy/).
