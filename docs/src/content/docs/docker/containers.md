---
title: Docker Containers
description: Inspect containers reported by the selected Colima Docker context.
---

`Containers` shows Docker containers for the selected running Colima profile.

![ColimaStack Containers screenshot](/screenshots/containers.png)

## What this view shows

- Container name or ID.
- Image.
- Published ports.
- State and status.
- Running container count.
- Docker context, socket, profile state, and VM address.

Running containers are highlighted as healthy. `dead` containers create a backend warning. Stopped, paused, exited, or restarting containers can still appear because the app lists all containers.

## How to get data to appear

1. Select a Docker-backed Colima profile.
2. Start it with `Start`.
3. Run or create containers in that Docker context.
4. Click `Refresh`.

Quick Start sample:

```sh
docker run -d --name colimastack-quickstart -p 8080:80 nginx:alpine
```

If you are using a named profile, use the matching context:

```sh
docker --context colima-<profile> ps --all
```

## Available actions

The view is read-only in the current source. It does not start, stop, restart, remove, inspect, or show logs for individual containers.

Related menu bar actions can open a published port in the browser, open `Containers`, copy container ID, copy image, and copy ports.

## Empty states

- `Runtime not available`: Colima diagnostics are not available.
- `Choose a profile`: no profile is selected.
- `Docker endpoint unavailable`: Docker CLI or the selected context is unavailable.
- `No containers`: Docker is available, but the selected context has no containers.
- `No matching containers`: the local search filter hides all rows.

## Source command

ColimaStack invokes:

```sh
docker --context <context> ps --all --no-trunc --format "{{json .}}"
```

See [Command API](/reference/command-api/) for context and error behavior. Use [Diagnostics](/features/diagnostics/) if Docker is unavailable.
