---
title: Workloads
description: Inspect pods and deployments running in Colima Kubernetes.
---

ColimaStack reads workloads with:

```sh
kubectl get pods -A -o json
kubectl get deployments -A -o json
kubectl top pods -A
```

## What to check

- namespace
- pod or deployment name
- readiness
- phase or status
- restart count
- age
- CPU and memory metrics when available

## Troubleshooting

If workloads are missing, check the current Kubernetes context:

```sh
kubectl config current-context
kubectl get pods -A
```
