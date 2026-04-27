---
title: Troubleshooting
description: Recover from missing tools, stopped profiles, Docker context errors, Kubernetes issues, and empty views.
---

Start with [Diagnostics](/features/diagnostics/). It runs the same checks ColimaStack uses to decide whether views can populate.

## Colima is missing

Symptom: `Colima is not installed`, `Colima setup required`, or no profiles appear.

Fix:

```sh
brew install colima
colima version
```

Restart ColimaStack or click `Refresh`.

## Profiles are empty

If `colima` is installed but no profiles exist, use `Create Profile` in `Profiles` or start a default profile:

```sh
colima start
```

Existing users should verify `COLIMA_HOME` if profiles live outside `~/.colima`.

## Docker is unavailable

Symptom: `Docker endpoint unavailable`, empty Docker views, or Diagnostics shows Docker unavailable.

Checks:

```sh
docker version
docker context show
docker --context colima version
```

For named profiles, use `colima-<profile>` as the context. Start the selected profile if it is stopped.

## Kubernetes is unavailable

Symptoms: `Kubernetes is disabled`, empty Cluster/Workloads/Services, or `kubectl` errors.

Checks:

```sh
kubectl version --client
kubectl config current-context
kubectl get nodes
```

Kubernetes must be enabled on the selected Colima profile. Metrics require `kubectl top` to work; missing metrics do not prevent resource lists from appearing.

## A view is empty

Empty can be normal:

- `Containers`: no containers exist in the selected Docker context.
- `Images`: no images exist in the selected Docker context.
- `Volumes`: no configured mounts or Docker volumes exist.
- `Networks`: Docker networks were not returned or search filtered them.
- `Workloads`: no pods or deployments exist.
- `Services`: no services exist.
- `Activity`: no app lifecycle command has run in this session.
- `Monitor`: no sample has been collected for a running Docker profile.

Clear search, click `Refresh`, and verify the selected profile.

## Commands fail

Open `Activity` for the app-level command label and output. Commands are redacted and capped before display. Use [Command API](/reference/command-api/) to compare the exact command shape.

## Logs are empty

ColimaStack reads:

```txt
$COLIMA_HOME/<profile>/daemon/daemon.log
```

If the file is missing, the app shows the expected path. Start the profile or check Colima's local files.
