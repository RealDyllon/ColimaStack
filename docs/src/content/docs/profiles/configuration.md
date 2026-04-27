---
title: Profile Configuration
description: Understand profile editor fields and how they map to Colima start flags.
---

Profile configuration is applied through Colima. ColimaStack validates basic input, then invokes `colima start` with flags derived from the editor.

## Runtime

The editor exposes `Runtime`, `VM Type`, and `Architecture`. Docker-backed profiles populate Docker inventory and Monitor data. Non-Docker runtimes do not populate Docker views in the current backend.

## Resources

`CPU`, `Memory`, and `Disk` become:

```txt
--cpus <count>
--memory <GiB>
--disk <GiB>
```

Monitor uses these values as capacity ceilings when calculating CPU, memory, and disk progress.

## Kubernetes

`Enable Kubernetes`, `Kubernetes Version`, `K3s Listen Port`, and `K3s Args` map to Colima Kubernetes flags. Kubernetes views require the profile to be running, Kubernetes enabled, and `kubectl` available.

## Network

The editor exposes `Expose VM Address`, network `Mode`, `Interface`, `DNS Resolvers`, and `Port Forwarder`. These map to Colima networking flags when supported by Colima.

## Mounts

Mount rows contain `Local Path`, `VM Path`, and `Writable`. ColimaStack validates filesystem paths before applying configuration. The `Volumes` page shows both these configured mounts and Docker-managed volumes.

## Advanced

`Rosetta` is enabled only for compatible `vz` settings in the UI. `Nested Virtualization` is enabled only for `vz`. `Additional CLI Args` are appended to the generated `colima start` command, so use them carefully.

## Applying changes

- New profile: the primary action is `Create`.
- Existing profile: the primary action is `Apply`.
- Existing profile names cannot be changed.
- Applying settings mutates the local Colima profile.

See [Command API](/reference/command-api/) for exact flag shapes and [Compatibility](/compatibility/) for support notes.
