# ColimaStack comprehensive mockup screen inventory

01. `01_empty_containers.png` — Containers
02. `02_empty_profiles.png` — Profiles
03. `03_empty_kubernetes_workloads.png` — Workloads
04. `04_empty_metrics.png` — Monitor
05. `05_empty_colima_not_installed.png` — Setup required
06. `06_empty_docker_unavailable.png` — Docker unavailable
07. `07_loading_refresh_in_progress.png` — Containers
08. `08_loading_command_running.png` — Starting profile
09. `09_loading_first_launch.png` — First launch
10. `10_loading_slow_cli_calls.png` — Slow command
11. `11_error_failed_start_stop.png` — Failed start
12. `12_error_bad_docker_context.png` — Bad Docker context
13. `13_error_kubernetes_unavailable.png` — Kubernetes unavailable
14. `14_error_permission_path_issues.png` — Permission issue
15. `15_profiles_switcher_behavior.png` — Profiles
16. `16_profiles_create_profile_flow.png` — Create profile
17. `17_profiles_edit_profile_flow.png` — Edit profile
18. `18_profiles_delete_confirmation.png` — Delete profile
19. `19_command_feedback_progress.png` — Activity
20. `20_command_feedback_logs.png` — Activity logs
21. `21_command_feedback_history.png` — Command history
22. `22_command_feedback_terminal_output_retry.png` — Terminal output
23. `23_container_actions_menu.png` — Containers
24. `24_container_actions_delete_confirmation.png` — Delete container
25. `25_container_actions_inspect.png` — Inspect container
26. `26_container_actions_logs_terminal_files.png` — Container details
27. `27_images_screen.png` — Images
28. `28_volumes_screen.png` — Volumes
29. `29_networks_screen.png` — Networks
30. `30_kubernetes_cluster_subview.png` — Cluster
31. `31_kubernetes_workloads_subview.png` — Workloads
32. `32_kubernetes_services_subview.png` — Services
33. `33_settings_general.png` — Settings
34. `34_settings_kubernetes.png` — Settings
35. `35_settings_networking.png` — Settings
36. `36_settings_integrations.png` — Settings
37. `37_settings_advanced.png` — Settings
38. `38_search_scope_filtering_results.png` — Search
39. `39_search_no_results.png` — Search
40. `40_responsive_compact_width.png` — Compact window
41. `41_responsive_sidebar_collapsed.png` — Collapsed sidebar
42. `42_responsive_table_overflow.png` — Table overflow
43. `43_dark_mode_overview.png` — Overview
44. `44_dark_mode_containers.png` — Containers
45. `45_accessibility_focus_keyboard_voiceover.png` — Accessibility
46. `46_design_system_component_states.png` — Design system
47. `47_design_system_specs_tokens.png` — Design tokens
48. `48_onboarding_first_run_welcome.png` — Welcome
49. `49_onboarding_missing_dependencies.png` — Setup checks
50. `50_onboarding_install_locate_dependencies.png` — Installing
51. `51_edge_long_container_names.png` — Edge cases
52. `52_edge_many_ports_volumes.png` — Edge cases
53. `53_edge_long_namespaces.png` — Edge cases
54. `54_edge_high_metric_values.png` — Edge cases
55. `55_edge_disconnected_cluster.png` — Edge cases
56. `56_container_start_confirmation.png` — Start container
57. `57_container_restart_confirmation.png` — Restart container

## Implementation reconciliation

Status values:

- Implemented: represented in the current app and covered by automated tests where practical.
- Partial: represented by a generic or adjacent state, but not yet proven against the exact mockup.
- Deferred: not currently implemented and must be explicitly descoped or built before claiming full mockup coverage.

Last reconciled: April 26, 2026 against `ColimaStack/Views`, `PreviewSupport`, and the passing Xcode suite. The individual numbered PNG files are not present in `design/mockups`; the filenames below are treated as inventory entries from the contact sheets.

| # | State | Status | Implementation note |
|---|---|---|---|
| 01 | Empty containers | Implemented | `ContainersScreen` shows no-container and no-match empty states. |
| 02 | Empty profiles | Implemented | `ProfilesScreen` and overview expose create-profile empty states. |
| 03 | Empty Kubernetes workloads | Implemented | `KubernetesWorkloadsScreen` shows no pods/deployments and disabled states. |
| 04 | Empty metrics | Implemented | `MonitorScreen` handles missing runtime samples and stopped profiles. |
| 05 | Colima not installed | Implemented | Overview/diagnostics show missing Colima dependency states. |
| 06 | Docker unavailable | Implemented | `ContainersScreen` shows Docker endpoint unavailable with refresh. |
| 07 | Refresh in progress | Implemented | Sidebar/overview expose refresh/loading state. |
| 08 | Command running | Implemented | Toolbar disables lifecycle actions and activity/overview show active operation. |
| 09 | First launch loading | Implemented | Overview shows startup diagnostics while diagnostics/profiles are loading. |
| 10 | Slow CLI calls | Partial | Active operation state exists; no elapsed-time-specific slow-call UI. |
| 11 | Failed start/stop | Implemented | Command failures are captured in command history and presented errors. |
| 12 | Bad Docker context | Partial | Diagnostics force Colima context and Docker unavailable copy exists; no dedicated bad-context mock state. |
| 13 | Kubernetes unavailable | Partial | Kubernetes screens show disabled/unavailable states; disconnected cluster errors are surfaced as backend issues. |
| 14 | Permission/path issues | Partial | Diagnostics and command errors surface failures; no dedicated permission remediation screen. |
| 15 | Profile switcher behavior | Implemented | Sidebar and profile roster select profiles and refresh selected details. |
| 16 | Create profile flow | Implemented | `ProfileEditorView` creates profiles with validation. |
| 17 | Edit profile flow | Implemented | `ProfileEditorView` edits selected profile configuration. |
| 18 | Delete confirmation | Implemented | Delete requires typing the captured profile name before the destructive action is enabled. |
| 19 | Command progress | Implemented | `activeOperation` drives toolbar disables and activity banners. |
| 20 | Activity logs | Implemented | Activity and overview show captured profile logs. |
| 21 | Command history | Implemented | `CommandLogEntry` records command, status, output, and errors. |
| 22 | Terminal output retry | Partial | Raw terminal output is shown; retry affordance is limited to rerunning toolbar actions. |
| 23 | Container actions menu | Partial | Menu bar exposes open/copy actions for containers; main container row actions are not implemented. |
| 24 | Container delete confirmation | Deferred | Container deletion is not a first-class GUI action. |
| 25 | Container inspect | Deferred | No dedicated inspect panel for container JSON/details. |
| 26 | Container logs/files | Deferred | Profile logs exist; per-container logs/files are not implemented. |
| 27 | Images screen | Implemented | `ImagesScreen` lists image records and empty/search states. |
| 28 | Volumes screen | Implemented | `VolumesScreen` lists Colima mounts and Docker volumes. |
| 29 | Networks screen | Implemented | `NetworksScreen` lists profile and Docker network data. |
| 30 | Kubernetes cluster | Implemented | `KubernetesClusterScreen` shows identity, nodes, and operator actions. |
| 31 | Kubernetes workloads | Implemented | `KubernetesWorkloadsScreen` shows pods and deployments. |
| 32 | Kubernetes services | Implemented | `KubernetesServicesScreen` shows services and ports. |
| 33 | Settings general | Implemented | Settings tab includes auto refresh and selected-section details. |
| 34 | Settings Kubernetes | Implemented | Settings tab includes Kubernetes status and profile actions. |
| 35 | Settings networking | Implemented | Settings tab includes context, address, socket, and mount type. |
| 36 | Settings integrations | Implemented | Settings tab lists diagnostic tool checks. |
| 37 | Settings advanced | Implemented | Settings tab exposes update/restart and history/log diagnostics. |
| 38 | Search results | Implemented | Route-scoped searchable views show result counts. |
| 39 | Search no results | Implemented | Search-aware screens show no-match states. |
| 40 | Compact width | Deferred | Main window still enforces a 900 point minimum width. |
| 41 | Sidebar collapsed | Partial | Native `NavigationSplitView` behavior applies; no explicit collapsed-sidebar evidence. |
| 42 | Table overflow | Partial | Record rows use truncation and scroll containers; no dedicated overflow fixture. |
| 43 | Dark mode overview | Partial | Native colors support dark mode and launch test captures dark mode; no overview screenshot assertion. |
| 44 | Dark mode containers | Partial | Native colors support dark mode; no containers dark-mode screenshot assertion. |
| 45 | Accessibility focus | Partial | Key controls have labels/identifiers; VoiceOver keyboard navigation is not audited. |
| 46 | Component states | Partial | Shared components exist, but no component-state gallery/test. |
| 47 | Design tokens | Partial | Shared styling exists in components, but no formal token/spec source. |
| 48 | First-run welcome | Deferred | No dedicated welcome/onboarding flow. |
| 49 | Missing dependencies | Implemented | Diagnostics and overview show missing dependency states. |
| 50 | Install/locate dependencies | Deferred | No guided installer or custom tool locator UI. |
| 51 | Long container names | Partial | Rows truncate long values; no edge fixture or screenshot evidence. |
| 52 | Many ports/volumes | Partial | Lists scroll and truncate; no high-cardinality fixture or screenshot evidence. |
| 53 | Long namespaces | Partial | Kubernetes rows truncate; no edge fixture or screenshot evidence. |
| 54 | High metric values | Partial | Metrics format bytes/percent values; no edge fixture or screenshot evidence. |
| 55 | Disconnected cluster | Partial | Backend issues can surface kubectl failures; no dedicated disconnected-cluster mock state. |
| 56 | Container start confirmation | Deferred | Container lifecycle actions are not implemented. |
| 57 | Container restart confirmation | Deferred | Container lifecycle actions are not implemented. |
