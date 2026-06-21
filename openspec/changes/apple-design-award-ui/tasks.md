# Tasks: apple-design-award-ui

> **Implementation status (last commit):** Group 1 (Design system
> foundation) is complete and building green. The Xcode project
> auto-includes files in `ColimaStack/` via a synchronized folder, so
> the new `ColimaStack/DesignSystem/` module is wired up without any
> `project.pbxproj` edits. Tasks 2.x–12.x are pending and will be
> implemented in subsequent PRs.

## 1. Design system foundation

- [x] 1.1 Create `ColimaStack/DesignSystem/` folder structure with `Tokens/` and `Primitives/` subfolders
- [x] 1.2 Implement `DesignSystem` namespace and `TextStyle` (display, title1, title2, title3, body, caption, code, mono) backed by `Font`
- [x] 1.3 Implement `ColorRole` (text/{primary,secondary,tertiary}, surface/{canvas,raised,sunken,inverse}, border/{subtle,strong}, accent/primary, status/{success,warning,critical,info,neutral}) using `Color(nsColor:)` and asset-catalog brand colors, with light/dark resolution
- [x] 1.4 Implement `Spacing` (xs 4, sm 8, md 16, lg 24, xl 32, 2xl 48), `Radius` (control 6, card 12, pill 999), `Elevation` (canvas/raised/sunken as `Material` and stroke combinations)
- [x] 1.5 Implement `Motion` (fast 150ms, default 220ms, slow 350ms; standard, emphasized, spring) with `shouldReduceMotion` override
- [x] 1.6 Port `SectionCard` to consume tokens (raised surface, subtle hairline, card radius, title3 title, caption subtitle)
- [x] 1.7 Port `MetricTile` to consume tokens (caption label, title3 value, color-role-driven state color)
- [x] 1.8 Port `StatusBanner` to consume tokens (icon `frame(width:)` for alignment, color-role-driven tints)
- [x] 1.9 Implement `EmptyStateView` with `kind: EmptyStateKind` (noResults, noData, loading, error, unavailable, disabled) consuming tokens; rename and remove `SurfaceStateView`
- [x] 1.10 Port `KeyValueGrid` to use `Grid` with token-driven spacing and truncation rules
- [x] 1.11 Implement `IconBadge` (rounded rectangle backdrop + icon + optional count) consuming tokens
- [x] 1.12 Port `StateDot` to consume `ColorRole` (success/info/warning/critical/neutral) and a 10pt diameter
- [x] 1.13 Implement `ToolbarActionButton` (icon-only with optional label) consuming tokens and respecting icon-only / icon+label / label-only toolbar modes
- [x] 1.14 Implement `PrimaryButton` and `DestructiveButton` with token-driven prominence (filled / tinted / borderless variants)
- [x] 1.15 Implement `Icon` namespace with semantic accessors (`Icon.brand`, `Icon.runtime.*`, `Icon.profile.*`, `Icon.kubernetes.*`, `Icon.action.*`, `Icon.section.*`, `Icon.empty.*`) sized via `.iconControl` (16pt), `.iconRow` (20pt), `.iconHero` (48pt)
- [x] 1.16 Add `BrandMark` asset to `Assets.xcassets` and reference from `Icon.brand`
- [x] 1.17 Add a SwiftLint custom rule that fails the build if `Image(systemName:`, `Color(`, `Color.`, or `nsColor:` appears in `ColimaStack/Views/**` outside of `DesignSystem/`
- [x] 1.18 Add a contrast-test XCTest case that asserts every (text role, surface role) pair used in the app passes WCAG 2.1 AA in both light and dark mode
- [x] 1.19 Migrate `OverviewScreen` to the new design system end-to-end as the reference implementation; capture before/after screenshots

## 2. Workspace chrome

- [x] 2.1 Add `NavigationSplitView` configuration with `.navigationSplitViewStyle(.balanced)`, sidebar material, and the new `ColumnWidth(min: 250, ideal: 280, max: 360)`
- [x] 2.2 Rewrite the toolbar using `ToolbarItem` / `ToolbarItemGroup` / `ControlGroup` (Refresh · spacer · Lifecycle ControlGroup · spacer · Auto Refresh toggle · flexible space · Run Diagnostics · Settings · About)
- [x] 2.3 Implement `NSToolbarController: NSViewControllerRepresentable` for items that need NSToolbar-level customization (initially empty; grows as needed)
- [x] 2.4 Set the window title to "ColimaStack"; remove `navigationTitle` from the sidebar; move the brand mark to a sidebar header that shows brand + tagline + selected profile summary
- [x] 2.5 Implement the secondary title line showing the active route name via `.toolbarTitleMenu` or `Window.titlebarAppearsTransparent` workaround
- [x] 2.6 Move `.searchable` to the toolbar with the route's `searchScopeLabel` as the prompt; bind `⌘F` to focus the search field
- [x] 2.7 Update `WindowGroup` `defaultSize` to 1100×760 and `minSize` to 920×620; verify auto-collapse below threshold
- [x] 2.8 Implement the runtime health footer in the sidebar (compact status line: "All systems operational" / "Docker disconnected" / etc.) with `Icon.health.ok` / `.degraded` / `.failed`
- [x] 2.9 Implement single-window policy: opening from the menu bar, dock, or deep link activates the existing window; `⌘N` opens a new one
- [x] 2.10 Add the `Window > Window` menu listing open windows by current route
- [x] 2.11 Update `ColimaStackMenuBarLabel` to use the new `Icon.profile.<state>` with the single colored mark; remove any text in the menu bar title
- [x] 2.12 Update `ColimaStackMenuBarMenu` structure: status header · Open Main Window · Refresh Now · Auto Refresh · profile section · runtime section · kubernetes section · diagnostics section · app section. Honor live updates via the existing event bus

## 3. Data tables

- [x] 3.1 Implement `TableContext` view modifier that wires a `Table` to a `Set<ResourceID>` selection, a density setting, and the contextual action bar
- [x] 3.2 Implement `TableContextualActionBar` (N selected, primary actions, dismissable) consuming `ToolbarActionButton`s
- [x] 3.3 Implement `TableDensity` (standard, compact) and the corresponding `defaultTableDensity` in `AppState`
- [x] 3.4 Implement `TableColumnCustomization` persistence per-resource in `AppState` (default column set + visibility + order)
- [x] 3.5 Migrate `ContainersScreen` to `Table` with columns (Name, Image, State, Status, Ports, Created), `sortUsing` comparators, selection, contextual action bar, row context menu (Start/Stop/Restart/Delete/Copy ID/Copy Image/Copy Ports/Open in Browser/Inspect/Logs)
- [x] 3.6 Migrate `ImagesScreen` to `Table` (Repository, Tag, Image ID, Size, Created, In Use By)
- [x] 3.7 Migrate `VolumesScreen`'s runtime-volumes list to `Table` (Name, Driver, Scope, Mountpoint, Size)
- [x] 3.8 Migrate `NetworksScreen`'s runtime-networks list to `Table` (Name, Driver, Scope, Internal, IPv6, ID)
- [x] 3.9 Migrate `KubernetesWorkloadsScreen` Pods list to `Table` (Name, Namespace, Node, Phase, Ready, Restarts, Age)
- [x] 3.10 Migrate `KubernetesWorkloadsScreen` Deployments list to `Table` (Name, Namespace, Ready, Updated, Available, Age)
- [x] 3.11 Migrate `KubernetesServicesScreen` Services list to `Table` (Name, Namespace, Type, Cluster IP, Ports, Age)
- [x] 3.12 Remove `RecordList` and `RecordRow` from `WorkspaceComponents.swift`; ensure no remaining references
- [x] 3.13 Implement `View > Table Density` menu command that toggles density; persist the choice
- [x] 3.14 Add XCTest covering column sort, multi-select, ⌘A, copy-with-context, contextual action bar visibility

## 4. Profile editor

- [x] 4.1 Implement `EditorSheet` SwiftUI wrapper with `.presentationDetents([.large])`, `.presentationDragIndicator(.visible)`, `.presentationBackground(.regularMaterial)`, 720×760 frame, sticky header
- [x] 4.2 Rewrite `ProfileEditorView` body as a `ScrollView { VStack { SectionCard { ... } } }` with cards: Profile, Resources, Kubernetes, Network, Mounts, Advanced
- [x] 4.3 Replace `Form`-style `Picker`/`Toggle` controls with custom label-left / control-right rows in a `Grid`
- [x] 4.4 Replace `Stepper` for CPU/Memory/Disk with `Slider` + live value label
- [x] 4.5 Replace network Mode `Picker` with `.segmented` style; ensure Interface `TextField` is disabled when Mode is "Shared"
- [x] 4.6 Replace Mounts row with inline editable list (Local Path / VM Path / Writable / Remove) and a footer "Add Mount" button
- [x] 4.7 Replace K3s Args and DNS Resolvers with inline editable list components
- [x] 4.8 Implement sticky validation footer with one-line summary and popover listing errors; disable Apply when errors exist or an active operation is running
- [x] 4.9 Implement destructive-recreation confirm dialog when changing runtime, vmType, or diskGiB on an existing profile
- [x] 4.10 Implement keyboard navigation: Name auto-focus on open, Tab order, Return moves to next control, ⌘. cancels, "Revert to defaults" overflow menu
- [x] 4.11 Add XCTest for keyboard navigation, validation footer state, and the destructive confirm dialog
- [x] 4.12 Add snapshot test for the open editor in both light and dark mode

## 5. Settings window

- [ ] 5.1 Rewrite `SettingsWindowView` as a `NavigationSplitView` with a 200pt sidebar `List` of categories and the right pane
- [ ] 5.2 Implement `SettingsPane` selection persistence in `AppState`
- [ ] 5.3 Rewrite `SettingsPaneContent` to render cards instead of `Form` sections
- [ ] 5.4 Compose the General pane from Refresh / Selected / About cards using `SectionCard` and `KeyValueGrid`
- [ ] 5.5 Compose the Kubernetes pane from Status / Actions cards
- [ ] 5.6 Compose the Networking pane from a single Endpoints card with copy affordances per row
- [ ] 5.7 Compose the Integrations pane from a single Toolchain card using a redesigned `ToolRow` (icon, name, version, status, copy path)
- [ ] 5.8 Compose the Advanced pane from Profile actions / Diagnostics cards
- [ ] 5.9 Wire ⌘1–⌘5 to jump to the matching category; ensure focus moves to the first control
- [ ] 5.10 Implement destructive-action confirmation for Reset Configuration
- [ ] 5.11 Add the window 720×560 default and 600×480 min size

## 6. Terminal log

- [ ] 6.1 Implement `LogLine` model (timestamp, stream: .stdout/.stderr/.system/.error, text)
- [ ] 6.2 Implement `LogStream` with append-only API and a 5000-line FIFO cap
- [ ] 6.3 Implement `LogTextStorage: NSTextStorage` with incremental append and stream-driven color rules
- [ ] 6.4 Implement `TerminalLogView: NSViewRepresentable` wrapping an `NSTextView` with line-number gutter, search field, copy-all, color rules
- [ ] 6.5 Implement auto-scroll-to-bottom with "Jump to live" affordance; bind `End` to jump-to-live
- [ ] 6.6 Implement toolbar (line-number toggle, search, copy-all, clear) consuming `ToolbarActionButton`
- [ ] 6.7 Wire `LogStream` to `StreamingProcessRunner` for container logs and to `RuntimeEventBus` for command output
- [ ] 6.8 Wire `LogStream` to the existing `appState.logs` string by parsing into `LogLine`s for the Overview and Activity views
- [ ] 6.9 Honor the system "Reduce motion" setting by disabling the auto-scroll fade
- [ ] 6.10 Add XCTest for FIFO eviction, search, color rules, and streaming append (no full re-render)

## 7. Container lifecycle

- [ ] 7.1 Implement `ContainerService` exposing async `start`, `stop`, `restart`, `delete`, `inspect`, `logs` on top of `CommandRunService` and `StreamingProcessRunner`
- [ ] 7.2 Record every container-lifecycle command as a `CommandLogEntry` in `AppState` with command, status, output, timing
- [ ] 7.3 Surface container row actions in the Containers table (context menu, contextual action bar, leading context-menu button)
- [ ] 7.4 Implement Delete confirmation dialog (one container, multi-container) with destructive + cancel buttons
- [ ] 7.5 Implement the `InspectPanel` (sheet) with metadata, configuration, networking, mounts, raw JSON sections; ⌘F search
- [ ] 7.6 Implement the Logs view (sheet) backed by `TerminalLogView` and `StreamingProcessRunner`; "tailing" indicator, auto-scroll, jump-to-live, ⌘F search, copy-all, line-number toggle
- [ ] 7.7 Ensure container state changes from CLI/UI update the table within 500ms via the event bus as a delta (not a full reload)
- [ ] 7.8 Add XCTest for the destructive dialog, the inspect panel, the logs streaming, and the row-action availability by state

## 8. Onboarding

- [ ] 8.1 Add a new `Window` scene to `ColimaStackApp` for `OnboardingWindow`; suppress the main window on first run
- [ ] 8.2 Implement first-run detection via `UserDefaults` flag `colimastack.didCompleteOnboarding`
- [ ] 8.3 Implement the Welcome step (brand mark, value prop, Get Started, Skip onboarding)
- [ ] 8.4 Implement the Dependency Check step using existing `ToolCheck`; per-tool row with install/locate actions
- [ ] 8.5 Implement the "Install with Homebrew" popover that shows the `brew install …` command and a Copy action
- [ ] 8.6 Implement the "Locate manually…" file picker for `limactl`
- [ ] 8.7 Implement the Profile Creation step (slimmed-down editor: Name, Runtime, Resources, Kubernetes toggle) with a "Create & Start" primary action
- [ ] 8.8 Implement progress view with the active operation label; advance to success when profile reaches `.running`
- [ ] 8.9 Implement error state with retry (form data preserved) and the success state with "Open Workspace" + "View Logs"
- [ ] 8.10 On success, write the flag and dismiss the onboarding window; open the main window to Overview
- [ ] 8.11 Add "Run onboarding again" and "Re-run dependency check" actions to Settings > Advanced
- [ ] 8.12 Add XCTest for flag persistence, each step's transitions, and the "Run again" flow

## 9. Empty states pass

- [ ] 9.1 Replace every bare `Text("No matching …").foregroundStyle(.secondary)` in `ColimaStack/Views/**` with `EmptyStateView`
- [ ] 9.2 Wire `EmptyStateView(kind: .loading, …)` for the initial load of every screen
- [ ] 9.3 Wire `EmptyStateView(kind: .noData, …)` with a primary action for Containers, Images, Volumes, Networks, Workloads, Services, Profiles, Activity
- [ ] 9.4 Wire `EmptyStateView(kind: .disabled, …)` for Kubernetes screens when Kubernetes is not enabled on the selected profile, with an "Enable Kubernetes" action
- [ ] 9.5 Wire `EmptyStateView(kind: .error, …)` with Retry + View Diagnostics for the failure cases on each screen
- [ ] 9.6 Implement the cross-fade transition between empty and data states (token-driven `Motion.default`)
- [ ] 9.7 Add a SwiftLint custom rule (or CI grep) that fails the build if a `Text("No …")` literal appears in view code

## 10. Motion and feedback

- [ ] 10.1 Replace every `withAnimation(.easeInOut(duration: …))` in view code with token-driven `Motion.*` animations
- [ ] 10.2 Implement the hover-state highlight modifier (1% black in light, 5% white in dark) on interactive rows, list items, table rows, sidebar rows, and command buttons
- [ ] 10.3 Implement the focus ring modifier (2pt `accent/primary`) on focusable controls; thicker ring in Increase Contrast mode
- [ ] 10.4 Implement the lifecycle-flash animation (success background tint 220ms in, 600ms out; failure critical tint) on profile and container rows
- [ ] 10.5 Implement the inline `ProgressView` in the trailing cell of rows under operation
- [ ] 10.6 Implement `ToastCenter` (SwiftUI overlay at top-right of main window; max 3 toasts; 5s auto-dismiss; hover to pause)
- [ ] 10.7 Wire toasts to lifecycle command results, with `Open Activity` / `View Log` actions for failures
- [ ] 10.8 Implement VoiceOver announcement throttling (max 1 announcement per 3 seconds) for state-change announcements
- [ ] 10.9 Add XCTest for reduce-motion override, toast stacking, and lifecycle flash

## 11. Accessibility

- [ ] 11.1 Audit and add `.accessibilityLabel` to every button, toggle, table row, sidebar row, card header, status indicator, metric tile
- [ ] 11.2 Add `.accessibilityHint` to non-obvious actions (Start/Stop/Restart on a row, etc.)
- [ ] 11.3 Use `.accessibilityElement(children: .combine)` for state dots + labels so VoiceOver reads "State: running" once
- [ ] 11.4 Implement dynamic-type support: ensure no truncation at any size; reflow metric tiles and card rows vertically below a threshold
- [ ] 11.5 Implement high-contrast mode: border opacity 8% → 24%, text contrast 90% → 100%; add "Force high contrast" toggle in Settings > General
- [ ] 11.6 Run the contrast test in both color modes; fix any failing token combinations
- [ ] 11.7 Implement `AccessibilityNotification.Announcement` for significant state changes (profile started/stopped, command failed, container unhealthy) with throttling
- [ ] 11.8 Add `Help > Keyboard Shortcuts` menu listing every shortcut grouped by surface
- [ ] 11.9 Add accessibility XCTest that walks the entire app and asserts every interactive control has a label and is reachable via Tab

## 12. Final polish and quality gates

- [ ] 12.1 Capture before/after screenshots for every screen in both light and dark mode; commit to `assets/screenshots/`
- [ ] 12.2 Update the design reconciliation table in `design/mockups/screen_inventory.md` to mark the relevant entries Implemented
- [ ] 12.3 Run the full test suite (`xcodebuild test -scheme ColimaStack -destination 'platform=macOS'`) and ensure green
- [ ] 12.4 Run `swift run openspec validate apple-design-award-ui` and resolve any issues
- [ ] 12.5 Run the SwiftLint custom rules; ensure no raw `Color`/`Font`/`Image(systemName:)` in screen code outside `DesignSystem/`
- [ ] 12.6 Manually verify: keyboard-only operation, VoiceOver pass, dynamic-type at max, increase-contrast, reduce-motion, dark mode, light mode, narrow window (920pt), wide window (1400pt+)
- [ ] 12.7 Update the user-facing docs in `docs/` to reflect the new editor, settings, container actions, and onboarding
- [ ] 12.8 Update `README.md` to advertise the onboarding flow and the container actions
- [ ] 12.9 Tag the change for archive with `openspec archive apple-design-award-ui`
