---
title: Quick Start
description: Open ColimaStack, start a Colima profile, run a sample container, and verify it appears in the app.
---

Goal: open ColimaStack, start a Colima profile, run a sample container, and verify it appears in the app.

## Prerequisites

- macOS 14 or later. See [Compatibility](/compatibility/) for the current support matrix.
- Colima and the Docker CLI for Docker inventory.
- `kubectl` only for the optional Kubernetes check.
- A local build of ColimaStack. Public notarized downloads are not documented as available yet; see [Install](/install/) for the current acquisition path.

## Step 1: Install or open ColimaStack

Existing Colima user:

1. Build or open ColimaStack from source.
2. Let the app run its startup checks.
3. Select an existing profile in the sidebar.

New Colima setup:

1. Install Colima and Docker CLI.
2. Build or open ColimaStack from source.
3. Use `Create Profile` in the Profiles sidebar if you do not already have a profile, or start `default` from Terminal with `colima start`.

Full install and build steps are in [Install](/install/).

## Step 2: Confirm prerequisites

Run the smallest useful checks:

```sh
colima version
docker version
```

For Kubernetes workflows:

```sh
kubectl version --client
```

If a command is missing, open [Diagnostics](/features/diagnostics/) or return to [Install](/install/).

## Step 3: Start or select a profile

In ColimaStack:

1. Open `Profiles`.
2. Select an existing profile, or choose `Create Profile`.
3. Use `Start` from the toolbar or menu bar if the selected profile is stopped.

Success looks like:

- The selected profile shows `Running`.
- `Overview` shows a Docker context and socket for Docker profiles.
- `Containers` no longer shows `Docker endpoint unavailable`.

Profile behavior and destructive actions are documented in [Profiles](/profiles/overview/).

## Step 4: Run a visible sample container

ColimaStack reads Docker inventory from the selected profile's Docker context. If your selected profile is the default Colima profile, run:

```sh
docker run -d --name colimastack-quickstart -p 8080:80 nginx:alpine
```

For a named profile, either switch Docker to that context or pass the context explicitly:

```sh
docker context use colima-<profile>
# or
docker --context colima-<profile> run -d --name colimastack-quickstart -p 8080:80 nginx:alpine
```

Then open `Containers` in ColimaStack and click `Refresh`. The container should appear with image `nginx:alpine`, state `running`, and a published port similar to `0.0.0.0:8080->80/tcp`.

Cleanup:

```sh
docker rm -f colimastack-quickstart
```

See [Docker Containers](/docker/containers/) for empty states and command details.

## Step 5: Optional Kubernetes verification

Kubernetes must be enabled on the selected Colima profile. In ColimaStack, open `Cluster`; if Kubernetes is disabled, use `Enable Kubernetes`.

Minimal terminal check:

```sh
kubectl config current-context
kubectl get nodes
```

Then open `Cluster`, `Workloads`, or `Services` in ColimaStack and click `Refresh`. Workload metrics appear only when `kubectl top` works for the cluster.

See [Kubernetes](/kubernetes/overview/) for supported resources and failure cases.

## Step 6: Troubleshooting links

- [Diagnostics](/features/diagnostics/) for missing tools, stopped profiles, Docker context errors, and Kubernetes context errors.
- [Install](/install/) for source builds and dependency setup.
- [Profiles](/profiles/overview/) for lifecycle actions.
- [Docker Containers](/docker/containers/) for container inventory.
- [Kubernetes](/kubernetes/overview/) for cluster checks.
- [Command API](/reference/command-api/) for exact command shapes.
