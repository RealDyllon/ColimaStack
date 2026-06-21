---
title: Security & Privacy
description: What ColimaStack executes, reads, stores, indexes, redacts, and mutates locally.
---

ColimaStack is a local macOS app. Source review does not show telemetry code. The app does invoke local command-line tools, read local Colima files, index local resource metadata for search, and copy selected values to the macOS pasteboard when you choose copy actions.

## Local command execution

The app locates and invokes these external tools:

- `colima`
- `docker`
- `kubectl`
- `limactl` for diagnostics checks

Tool lookup uses the process `PATH` plus fallback paths: `/opt/homebrew/bin`, `/usr/local/bin`, `/opt/local/bin`, `/usr/bin`, `/bin`, `/usr/sbin`, and `/sbin`.

For managed Docker and Kubernetes commands, ColimaStack forwards a small environment allowlist: `COLIMA_HOME`, `KUBECONFIG`, `DOCKER_HOST`, `DOCKER_CONTEXT`, and proxy variables. Process output is captured locally for UI state, diagnostics, and activity.

Exact command shapes are documented in [Command API](/reference/command-api/).

## Files and directories read

ColimaStack reads:

- `$COLIMA_HOME` when set, otherwise `~/.colima`.
- Profile configuration at `$COLIMA_HOME/<profile>/colima.yaml`.
- Default template at `$COLIMA_HOME/_templates/default.yaml`.
- SSH config at `$COLIMA_HOME/ssh_config`.
- Colima daemon log at `$COLIMA_HOME/<profile>/daemon/daemon.log`.
- Docker and Kubernetes metadata returned by the `docker` and `kubectl` CLIs.

The app does not implement a separate network client for telemetry in the reviewed source. External CLIs may contact registries, Docker endpoints, Kubernetes API servers, or Colima/Lima services according to their own configuration.

## Stored, cached, and indexed data

In memory, the app keeps:

- Current profile list and selected profile.
- Docker containers, images, volumes, networks, stats, and disk usage for the selected running Docker profile.
- Kubernetes nodes, namespaces, pods, services, deployments, and metrics when Kubernetes is enabled.
- Up to 90 monitor samples per profile.
- Up to 200 command history entries.
- Selected profile logs capped to the last 200,000 characters.

The process runner caps each stdout and stderr stream at 1,048,576 bytes and marks truncated output.

Search is local. The search index covers profiles, Docker resources, Kubernetes resources, backend issues, and command history. It does not search registries, remote clusters beyond the data already returned by `kubectl`, or files outside the app's collected local state.

## Redaction behavior

The source redacts common secret patterns before storing or displaying command arguments, environment overrides, stdout, stderr, diagnostics text, logs, and search tokens.

Redacted names and patterns include:

- `PASSWORD` and `PASSWD`
- `SECRET`
- `TOKEN`
- `API_KEY` / `API-KEY`
- `ACCESS_KEY` / `ACCESS-KEY`
- `PRIVATE_KEY` / `PRIVATE-KEY`
- `AUTHORIZATION`
- `CREDENTIAL`
- bearer/basic authorization strings
- JSON fields with matching sensitive names
- CLI flags such as `--password`, `--secret`, `--token`, `--api-key`, and related forms

Kubernetes and Docker output is redacted only through those generic patterns. Docker labels, Kubernetes labels, image names, container commands, and environment-like strings may still be visible if they do not match the redaction rules.

## Mutating operations

Profile operations mutate local Colima state:

- `Start`
- `Stop`
- `Restart`
- `Delete`
- `Update Profile`
- `Enable Kubernetes` / `Disable Kubernetes`
- `Create Profile`
- `Edit Profile`

`Delete` requires app-level confirmation by typing the profile name, then invokes Colima's non-interactive delete command.

Docker and Kubernetes resource views are read-only in the current source. The menu bar can open browser URLs for published ports and copy IDs, image names, ports, contexts, sockets, mountpoints, and diagnostics summaries.

## User control

Copy actions write the visible value directly to the macOS pasteboard. There is no extra redaction at copy time beyond the redaction already applied to the displayed data.

Use [Diagnostics](/features/diagnostics/) to inspect missing tools and runtime errors, and [Activity and Logs](/features/activity/) to review command outcomes.
