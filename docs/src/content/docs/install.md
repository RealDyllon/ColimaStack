---
title: Install
description: Set up ColimaStack and the command-line tools it controls.
---

ColimaStack is a macOS app that controls local tools installed on your machine. It does not replace Colima, Docker, or kubectl. It makes those tools visible and easier to operate.

## Requirements

- macOS
- Colima
- Docker CLI
- kubectl for Kubernetes workflows
- Lima or `limactl` for deeper runtime diagnostics

## Install dependencies

Install the standard toolchain with Homebrew:

```sh
brew install colima docker kubectl lima
```

Start a default Colima profile from Terminal if you want to verify the CLI path before opening the app:

```sh
colima start
docker context use colima
docker ps
```

## App installation

For local release-candidate builds, use the signed and notarized ColimaStack app bundle produced by the release process. The current repository also includes release-readiness notes in [Release Readiness](/reference/release-readiness/).

## Replacing Docker Desktop

ColimaStack is not a Docker engine by itself. If you are moving away from Docker Desktop, install Colima and use the Colima Docker context:

```sh
docker context use colima
```

Named profiles use context names like `colima-work`.

## Running side-by-side

You can keep Docker Desktop and Colima installed together. Switch contexts explicitly:

```sh
docker context use colima
docker context use desktop-linux
```

ColimaStack focuses on Colima contexts. If Docker points at a non-Colima context, diagnostics should call that out.
