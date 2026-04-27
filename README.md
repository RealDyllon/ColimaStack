<p align="center">
  <img src="assets/ColimaStack-Logo-Wordmark.png" alt="ColimaStack" width="100%">
</p>

<p align="center">
  A native macOS control center for Colima profiles, Docker resources, and Kubernetes development clusters.
</p>

ColimaStack gives [Colima](https://github.com/abiosoft/colima) a focused graphical workspace for local container development. It helps you inspect runtime health, manage profiles, browse Docker inventory, view Kubernetes resources, and diagnose toolchain issues without hiding the command-line tools doing the work.

> [!NOTE]
> ColimaStack is not a container engine. It controls and inspects local tools such as `colima`, plus optional integrations like `docker`, `kubectl`, and `limactl` when those tools are installed.

## Features

- **Profile management**: create, edit, start, stop, restart, update, and delete Colima profiles.
- **Runtime overview**: view profile state, Docker context, socket, address, resources, Kubernetes status, recent activity, and logs.
- **Docker inventory**: browse containers, images, volumes, networks, runtime stats, and Docker disk usage.
- **Kubernetes visibility**: inspect nodes, namespaces, pods, deployments, services, and metrics when Kubernetes is enabled.
- **Diagnostics**: check `colima`, optional tool availability, Docker context, and Kubernetes context health.
- **Command transparency**: review active operations, command history, stdout, stderr, and Colima daemon logs.
- **Menu bar access**: check runtime state and jump back into the main workspace from the macOS menu bar.

## Requirements

- macOS 14 or later
- Homebrew-managed Colima CLI:

```sh
brew install colima
```

Optional tools unlock additional views and diagnostics:

- Install the Docker CLI only if you want Docker runtime inventory such as containers, images, volumes, networks, stats, and disk usage.
- Install `kubectl` only for Kubernetes workflows.
- Homebrew normally installs Lima with Colima; if diagnostics report that `limactl` is missing, install Lima explicitly.

```sh
brew install docker
brew install kubectl
brew install lima
```

## Documentation

The documentation site is built with Astro Starlight and is published at [colimastack.dyllon.io](https://colimastack.dyllon.io/).

Useful docs entry points:

- [Quick Start](https://colimastack.dyllon.io/quick-start/)
- [Install](https://colimastack.dyllon.io/install/)
- [Architecture](https://colimastack.dyllon.io/architecture/)
- [Command API](https://colimastack.dyllon.io/reference/command-api/)

If you want to contribute, see [CONTRIBUTING.md](CONTRIBUTING.md) for local development, testing, documentation, and release workflow details.

## How It Works

ColimaStack is a local-first macOS app. It calls the Colima CLI for profile lifecycle operations, uses Docker CLI JSON output for Docker runtime inventory when the Docker CLI is installed, reads Kubernetes state through `kubectl` when Kubernetes support is installed, and loads selected Colima files such as profile configuration, SSH config, and daemon logs.

Most profile-scoped operations use the `COLIMA_PROFILE` environment variable so the active app selection maps directly to the intended Colima runtime.

## Current Scope

This repository contains the macOS app, tests, and documentation for the current launch surface. Some documented workflows still require final smoke testing against a live Colima installation before release.
