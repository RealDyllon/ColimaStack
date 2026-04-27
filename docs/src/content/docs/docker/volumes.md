---
title: Docker Volumes
description: Inspect profile mounts and Docker-managed volumes for the selected Colima context.
---

`Volumes` combines two local storage views: configured Colima profile mounts and Docker-managed volumes from the selected context.

## What this view shows

- Profile-defined host mounts, VM paths, and writable/read-only state.
- Docker volume name, driver, scope, mountpoint, and labels.

## How data appears

Profile mounts come from the selected profile configuration. Docker volumes appear when Docker reports volumes in the selected Colima context:

```sh
docker volume create colimastack-demo
```

For named profiles:

```sh
docker --context colima-<profile> volume ls
```

Click `Refresh` after creating or removing volumes from Terminal.

## Available actions

The view is read-only in the current source. Remove and inspect actions are not implemented in the main app UI.

The menu bar can reveal configured profile mount locations and copy Docker volume mountpoints for the first reported volumes.

## Empty states

- `Volume surface unavailable`: Colima diagnostics are unavailable.
- `Select a profile`: storage data is scoped to one profile.
- `No mounts configured for this profile`: there are no configured Colima mounts.
- `No runtime volumes found`: Docker returned no volumes for the selected context.
- Search-specific empty messages mean local filtering matched no rows.

## Source command

ColimaStack invokes:

```sh
docker --context <context> volume ls --format "{{json .}}"
```

See [Command API](/reference/command-api/) and [Diagnostics](/features/diagnostics/).
