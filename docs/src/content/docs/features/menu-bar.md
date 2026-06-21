---
title: Menu Bar App
description: Use the ColimaStack menu bar for profile, Docker, Kubernetes, diagnostics, copy, and navigation actions.
---

The menu bar is a main interaction surface, not only a launcher. It reflects selected-profile state and exposes common runtime actions.

## Status area

The top status section shows one of:

- active operation label
- `Refreshing runtime data`
- `<profile> - <state>`
- runtime label
- Docker context
- `No active profile`
- `Colima setup required`

The menu bar icon also changes for running, starting/stopping, stopped, degraded, broken, and unknown profile states.

## App actions

| Action | What it does | Preconditions |
| --- | --- | --- |
| `Open ColimaStack` | Opens or focuses the main window. | None |
| `Refresh` | Runs diagnostics, profile discovery, selected profile refresh, and backend inventory when applicable. | Disabled while refreshing |
| `Auto Refresh` | Toggles automatic refresh. | None |
| `Settings...` | Opens Settings. | None |
| `About ColimaStack` | Opens the macOS about panel. | None |
| `Quit ColimaStack` | Quits the app. | None |

## Profiles menu

When no profiles exist, `Create Profile...` opens the main window and profile editor.

For each profile:

| Action | What it does | Mutates state |
| --- | --- | --- |
| `Select` | Selects the profile and refreshes it. | No |
| `Selected` | Indicates current selection. | No |
| `Start` | Starts the profile. | Yes |
| `Stop` | Stops the profile. | Yes |
| `Restart` | Restarts the profile. | Yes |
| `Edit Profile...` | Opens the profile editor. | Only when `Apply` is used |
| `Copy Docker Context` | Copies the profile Docker context. | No |
| `Copy Socket Path` | Copies the profile socket path. | No |
| `Reveal Profile Folder` | Opens Finder at the profile config location. | No |

Lifecycle buttons are disabled while another operation is active.

## Selected Profile menu

The selected-profile menu repeats lifecycle controls and adds:

- `Update Profile`
- `Edit Profile...`
- `Open Activity Logs` when logs are available
- `Reveal Profile Folder`

If no profile is selected, it offers `Create Profile...`.

## Docker Resources menu

When Docker data is available:

- `Containers`: lists up to 12 containers. Container submenus can `Open in Browser` for the first published HTTP/HTTPS-like port, `Open Containers View`, `Copy Container ID`, `Copy Image`, and `Copy Ports`.
- `Ports & Services`: lists up to 12 published ports and opens them in the browser.
- `Volumes & Mounts`: reveals up to 8 profile mounts and copies up to 8 Docker volume mountpoints.
- `Open Containers`, `Open Images`, and `Open Volumes` navigate to those views.

When Docker data is unavailable, `Open Runtime View` navigates to `Containers` and is disabled if no profile is selected.

## Kubernetes menu

| Action | What it does | Preconditions |
| --- | --- | --- |
| `Enable Kubernetes` / `Disable Kubernetes` | Runs Colima Kubernetes toggle for the selected profile. | Selected profile; disabled during active operation |
| `Restart Profile` | Restarts the selected profile. | Selected profile; disabled during active operation |
| `Open Cluster` | Opens `Cluster`. | Selected profile |
| `Open Workloads` | Opens `Workloads`. | Selected profile |
| `Open Services` | Opens `Services`. | Selected profile |

When Kubernetes data is available, the menu also shows node, pod, and service counts.

## Diagnostics menu

- `Run Checks`: refreshes runtime data and opens `Diagnostics`.
- `Open Diagnostics`: opens `Diagnostics`.
- `Open Activity`: opens `Activity`.
- `Copy Diagnostics Summary`: copies a short summary containing profile, Colima state, Docker availability/context, resource counts, and issue count.

## Failure and disabled states

Actions that mutate runtime state are disabled while another command is active. Missing profile or missing backend data reduces the menu to navigation or setup actions. Use [Diagnostics](/features/diagnostics/) when a command fails.

Related pages: [Profiles](/profiles/overview/), [Docker Containers](/docker/containers/), [Kubernetes](/kubernetes/overview/), and [Diagnostics](/features/diagnostics/).
