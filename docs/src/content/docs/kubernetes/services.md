---
title: Services
description: Inspect Kubernetes services for local development traffic.
---

Services are read with:

```sh
kubectl get services -A -o json
```

## What to check

- namespace
- service name
- type
- cluster IP
- external IP
- ports
- age

## Local access

Colima networking behavior depends on the profile and Kubernetes configuration. Use `kubectl describe service` and Colima networking settings when a service is not reachable from macOS.
