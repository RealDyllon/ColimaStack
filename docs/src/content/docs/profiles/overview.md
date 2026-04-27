---
title: Profiles
description: Create, select, start, stop, restart, update, edit, and delete Colima profiles.
---

`Profiles` is the profile roster and lifecycle view. It is scoped to local Colima profiles returned by `colima list --json`.

## What this view shows

- Total profile count.
- Running profile count.
- Kubernetes-enabled profile count.
- Runtime count.
- Profile roster with name, runtime, Kubernetes state, selected state, resource allocation, and current state.
- Selected profile paths for configuration, template, SSH config, and Lima override.

## How profile data appears

ColimaStack loads profiles from Colima, then refreshes selected-profile status. Existing Colima users should see profiles automatically after the app launches. New users can choose `Create Profile`.

If no profiles appear, open [Diagnostics](/features/diagnostics/) and confirm `colima` is available.

## Available actions

- `Create Profile`: opens the profile editor with default settings.
- `Edit Selected`: opens the profile editor for the selected profile.
- `Start`: starts the selected profile.
- `Stop`: stops the selected profile.
- `Restart`: restarts the selected profile.
- `Update Profile`: runs Colima update for the selected profile from Settings or menu bar.
- `Delete`: requires typing the profile name before ColimaStack runs the delete command.
- `Enable Kubernetes` / `Disable Kubernetes`: toggles Kubernetes for the selected profile.

Editing an existing profile uses the `Apply` action. Profile renaming is blocked; create a new profile instead.

Delete is destructive. The confirmation message states that it permanently deletes the Colima profile, including its VM and data.

## Profile configuration fields

The profile editor exposes:

- `Name`
- `Runtime`
- `VM Type`
- `Architecture`
- `CPU`, `Memory`, `Disk`
- `Enable Kubernetes`
- `Kubernetes Version`
- `K3s Listen Port`
- `K3s Args`
- `Expose VM Address`
- Network `Mode`
- `Interface`
- `DNS Resolvers`
- `Mount Driver`
- `Local Path`, `VM Path`, and `Writable` mount fields
- `Port Forwarder`
- `Rosetta`
- `Nested Virtualization`
- `Additional CLI Args`

Settings are applied through `colima start` flags. Some options are delegated to Colima and may depend on VM type, architecture, or host support.

## Safe and unsafe mutations

Starting, stopping, restarting, updating, and toggling Kubernetes mutate the selected local runtime. Delete is irreversible through the app. Docker and Kubernetes inventory pages are read-only in the current source.

## Empty states

- `No profiles configured`: Colima is installed but `colima list --json` returned no profiles.
- `Colima is not installed`: the app could not locate `colima`.
- Search-specific empty states mean local filtering matched no profiles.

## Related pages

- [Profile Configuration](/profiles/configuration/)
- [Docker Containers](/docker/containers/)
- [Kubernetes](/kubernetes/overview/)
- [Command API](/reference/command-api/)
- [Compatibility](/compatibility/)
