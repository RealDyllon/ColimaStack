---
title: Docker Volumes
description: Inspect persistent Docker volumes in the active Colima context.
---

Volumes are read with:

```sh
docker volume ls --format json
```

Volumes are often the most important local state in a development environment. Review them before deleting or rebuilding a Colima profile.

## Good cleanup practice

- Stop containers before removing volumes.
- Confirm the selected Docker context is a Colima context.
- Back up project data before deleting named volumes.
