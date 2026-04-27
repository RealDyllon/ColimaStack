---
title: Install
description: Set up ColimaStack and the command-line tools it controls.
---

ColimaStack is a macOS app that controls local tools installed on your machine. It does not replace Colima, Docker, or kubectl. Colima is the core dependency; Docker CLI and kubectl are optional integrations for the workflows that use them.

## Core requirements

- macOS
- Colima

## Optional integrations

- Docker CLI for Docker runtime inventory
- kubectl for Kubernetes workflows
- Lima or `limactl` for deeper runtime diagnostics, normally installed by Homebrew with Colima

## Install dependencies

Install the core Colima dependency with Homebrew:

```sh
brew install colima
```

Install optional tools only for the workflows you plan to use:

```sh
brew install docker
brew install kubectl
```

The Docker CLI enables ColimaStack's Docker resource views for containers, images, volumes, networks, stats, and disk usage. `kubectl` enables Kubernetes inventory views. If ColimaStack diagnostics report that `limactl` is missing, install Lima explicitly with `brew install lima`.

Start a default Colima profile from Terminal if you want to verify the core CLI path before opening the app:

```sh
colima start
```

If you installed the Docker CLI, verify the Docker context separately:

```sh
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
