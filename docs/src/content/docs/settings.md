---
title: Settings
description: App settings panes and profile actions exposed by ColimaStack.
---

Settings are available from the app menu bar and main app support area. They show app state and selected-profile controls; detailed profile editing happens in the profile editor.

## General

`General` includes:

- `Auto refresh`
- `Auto refresh frequency`
- selected profile
- active section
- refresh state

Auto-refresh frequencies are `Faster`, `Fast`, and `Normal`.

## Kubernetes

`Kubernetes` includes:

- enabled yes/no
- version
- context
- `Enable Kubernetes` / `Disable Kubernetes`
- `Edit Profile`

Kubernetes actions require a selected profile and are disabled while another operation is active.

## Networking

`Networking` shows:

- Docker context
- address
- socket
- mount type

## Integrations

`Integrations` shows the Diagnostics tool checks for `colima`, `docker`, `kubectl`, and `limactl`.

## Advanced

`Advanced` includes:

- `Update Profile`
- `Restart Profile`
- command history entry count
- logs captured yes/no
- diagnostics message count

For profile editor fields such as runtime, VM type, architecture, mounts, networking, Rosetta, and nested virtualization, see [Profile Configuration](/profiles/configuration/).
