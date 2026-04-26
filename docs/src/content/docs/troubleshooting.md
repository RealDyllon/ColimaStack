---
title: Troubleshooting
description: Recover from missing tools, bad Docker contexts, Kubernetes issues, and command failures.
---

Start with Diagnostics when ColimaStack does not show expected runtime data.

## Colima is missing

Install Colima and refresh diagnostics:

```sh
brew install colima
```

## Docker is unavailable

Verify the Docker CLI is installed and points at the expected context:

```sh
docker context ls
docker context use colima
docker ps
```

For a named Colima profile, use `colima-<profile>`.

## Kubernetes is unavailable

Confirm Kubernetes is enabled for the selected profile:

```sh
colima kubernetes start
kubectl config current-context
kubectl get nodes
```

If workload metrics are empty, verify that metrics support is installed in the cluster.

## Commands fail

Open Activity to review recent commands and terminal output. ColimaStack records command progress and failure output so you can retry from the app or reproduce the command in Terminal.

## Logs are empty

ColimaStack reads daemon logs from `$COLIMA_HOME/<profile>/daemon/daemon.log`. If no log file exists, the app shows the expected path.
