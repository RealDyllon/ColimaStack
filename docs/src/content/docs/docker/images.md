---
title: Docker Images
description: Inspect local images available to the selected Colima Docker context.
---

Images are read with:

```sh
docker images --format json
```

Use Images to find local build artifacts, old tags, and large images that contribute to local disk usage.

## Useful terminal checks

```sh
docker images
docker system df
```

ColimaStack surfaces Docker system disk usage in runtime snapshots where available.
