---
title: Docker Containers
description: Inspect containers running in the selected Colima Docker context.
---

ColimaStack reads containers with:

```sh
docker ps -a --format json
```

The Containers screen is scoped to the selected Colima profile and its Docker context.

## What to check

- container name and ID
- image
- status
- ports
- labels
- creation time
- runtime health where available

## Common workflow

1. Start the selected Colima profile.
2. Confirm the Docker context is the expected Colima context.
3. Open Containers.
4. Refresh after starting or stopping services from Terminal or Compose.

## Compose projects

Compose containers appear in the same Docker inventory. Use labels and container names to identify project membership.
