---
title: Docker Networks
description: Inspect Docker networks attached to the selected Colima profile.
---

Networks are read with:

```sh
docker network ls --format json
```

Use Networks to inspect Compose-created networks, default bridge networks, and runtime connectivity state.

## Related Colima settings

Profile networking can also involve:

- network address enablement
- DNS resolvers
- network mode
- network interface
- port forwarder

See [Profile Configuration](/profiles/configuration/) for settings that affect Colima networking.
