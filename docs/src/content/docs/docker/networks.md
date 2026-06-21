---
title: Docker Networks
description: Inspect profile networking and Docker networks attached to the selected Colima context.
---

`Networks` shows Colima endpoint details and Docker networks for the selected profile.

## What this view shows

- VM row with profile state, network address, and socket when available.
- Docker row with Docker readiness, context, and version.
- Address, Docker context, socket, and Kubernetes context.
- Docker network name, ID, driver, scope, internal flag, and IPv6 flag.

Docker's default `bridge`, `host`, and `none` networks may appear when Docker returns them for the selected context.

## How networks appear

Start a Docker-backed Colima profile and click `Refresh`. Networks are read from the selected Docker context:

```sh
docker network ls
```

For named profiles:

```sh
docker --context colima-<profile> network ls
```

## Available actions

The view is read-only in the current source. Inspect and remove actions are not implemented in the app UI.

## Empty states

- `Networking checks unavailable`: Colima diagnostics are unavailable.
- `Select a profile`: network state is scoped to a profile.
- `No network records matched`: local search filtered out the generated endpoint rows.
- `No Docker networks found`: Docker returned no networks for the selected context or Docker data is unavailable.

## Source command

ColimaStack invokes:

```sh
docker --context <context> network ls --no-trunc --format "{{json .}}"
```

See [Command API](/reference/command-api/) and [Diagnostics](/features/diagnostics/).
