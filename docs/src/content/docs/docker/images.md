---
title: Docker Images
description: Inspect local images available to the selected Colima Docker context.
---

`Images` shows image records from the selected running Colima Docker context.

## What this view shows

- Repository.
- Tag.
- Image ID.
- Digest.
- Size.
- Created time.
- Docker version and context.

## How images appear

Images appear when they exist in the selected Docker context. Pulling, building, or running a container can create image records:

```sh
docker pull nginx:alpine
```

For named profiles:

```sh
docker --context colima-<profile> pull nginx:alpine
```

Then click `Refresh`.

## Available actions

The view is read-only in the current source. Pull, remove, tag, inspect, and prune actions are not implemented in the app UI.

## Empty states

- `Image tooling unavailable`: Colima or Docker tooling is missing.
- `No profile selected`: select a profile first.
- `Docker image store unavailable`: Docker is not reachable for the selected profile.
- `No images`: the selected context has no images returned by Docker.
- `No matching images`: local search filtered the list.

## Source command

ColimaStack invokes:

```sh
docker --context <context> images --digests --no-trunc --format "{{json .}}"
```

See [Command API](/reference/command-api/) for exact command behavior and [Diagnostics](/features/diagnostics/) for missing tools or context failures.
