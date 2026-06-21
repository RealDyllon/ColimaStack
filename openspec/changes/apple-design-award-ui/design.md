## Context

ColimaStack is a SwiftUI macOS 14+ app with a 16K-line `AppState`, ~20 service classes, and four view files (`ContentView.swift`, `MainWindowView.swift`, `MenuBarView.swift`, `WorkspaceComponents.swift`, `WorkspaceScreens.swift`). The view layer was built quickly to ship features; the design system is implicit. There is a real set of design mockups under `design/mockups/` (light-mode overview, settings, contact sheets) that the implementation never converged on. The deployment target is macOS 14 so SwiftUI `Table` (macOS 12+), `NavigationSplitView` (13+), `.scrollPosition`, `.searchable` placements, and `Inspector` are all available.

The codebase has working `RuntimeEventBus` and per-resource event sources. The backend services can already produce the data the new UI needs; no new CLI work is required. The Container resource model needs new affordances (Start/Stop/Restart/Delete) but the underlying `docker` commands are already invoked elsewhere; a thin `ContainerService` will sit on top of the existing `CommandRunService` and `StreamingProcessRunner`.

This change touches every visible surface. It introduces a real design system module, replaces the Form-based editor and settings, replaces `RecordList`/`RecordRow` with `Table`, adds the deferred container-lifecycle and onboarding flows, and tightens accessibility. It is the largest single UI change in the project to date.

## Goals / Non-Goals

**Goals:**
- One design system consumed by every view (no raw `Color`/`Font` literals outside `DesignSystem`).
- Native macOS chrome (real `NSToolbar`, `unifiedCompact` title bar, sidebar material, system table behaviors).
- A polished, accessible profile editor and settings window that match the rest of the app.
- First-class container lifecycle, inspect, and logs.
- A first-run onboarding flow that ships a new user to a running profile in three steps.
- WCAG 2.1 AA contrast, full keyboard navigation, VoiceOver labels, dynamic type, high contrast, reduced motion.
- "Apple Design Award credible" polish: smooth motion, focus rings, hover states, toast notifications, contextual action bars.

**Non-Goals:**
- Changing the runtime/event-bus architecture (out of scope; specs unchanged).
- Adding new CLI commands or backend functionality beyond what already exists.
- A custom design tool or Figma-style design system export.
- iOS / iPadOS / visionOS variants (macOS-only).
- Internationalization beyond English for this change (the strings and layout are still English-only; token-based design makes future i18n cheaper but it is not in scope).
- Light/dark mode toggles in the app (the design system follows the system setting; user override is a stretch goal).
- Cloud sync, sharing, or accounts.

## Decisions

### 1. New `DesignSystem` module split out of `WorkspaceComponents.swift`

`WorkspaceComponents.swift` is split into:
- `ColimaStack/DesignSystem/` — a new folder containing:
  - `DesignSystem.swift` (namespace)
  - `Tokens/TextStyle.swift`, `ColorRole.swift`, `Spacing.swift`, `Radius.swift`, `Elevation.swift`, `Motion.swift`
  - `Primitives/SectionCard.swift`, `MetricTile.swift`, `StatusBanner.swift`, `EmptyStateView.swift`, `KeyValueGrid.swift`, `IconBadge.swift`, `StateDot.swift`, `ToolbarActionButton.swift`, `PrimaryButton.swift`, `DestructiveButton.swift`
  - `Icon.swift` (the icon vocabulary)
- `ColimaStack/Views/Components/` — the per-feature composite components that consume the primitives (table cells, contextual action bar, inspector header, etc.).

The existing `RecordList` and `RecordRow` are deleted (replaced by `Table` in each feature screen).

**Why:** A token-driven design system is the only way to enforce consistency at this scale. The mockups in `design/mockups/` use a token-style hierarchy and the implementation has been drifting from them because every view hand-rolls its own spacing/colors.

**Alternatives considered:**
- Extend `WorkspaceComponents.swift` in place. Rejected because the file would grow past 2000 lines and there is no token layer to anchor new views to.
- Use a third-party design system (e.g. custom SwiftUI wrapper). Rejected because the system APIs (color, typography, material) are already good enough; we just need our own token layer over them.

### 2. Toolbar uses SwiftUI `.toolbar` with an `NSViewControllerRepresentable` shim where needed

SwiftUI's `.toolbar` is the right API for 95% of the toolbar. The 5% that needs a real `NSToolbar` (e.g. some customizable items, system-provided `Toggle` styling) is wrapped in a small `NSToolbarController: NSViewControllerRepresentable` that hosts an `NSToolbar` instance and bridges events back to SwiftUI bindings.

**Why:** The current `ToolbarItemGroup` with `Divider()` between items is the wrong abstraction. Native `.toolbar` is much closer to what an Apple Design Award submission looks like.

**Alternatives considered:**
- Pure SwiftUI `.toolbar`. Rejected because the toolbar needs to be customizable and some of the items need NSToolbar-level styling.
- Drop SwiftUI `.toolbar` entirely and build an `NSToolbar` from scratch. Rejected because the SwiftUI path handles 95% of the work and we can keep the bindings.

### 3. `Table` is used for every resource list; per-screen column customization is exposed

Every resource screen (Containers, Images, Volumes, Networks, Pods, Deployments, Services) renders its records as a SwiftUI `Table`. Column visibility and order are stored in `AppState` so the user's choice persists across launches. The default column set and order come from the spec; the user can right-click a column header to show/hide/reorder.

**Why:** `Table` gives us sort, selection, keyboard nav, copy-with-context, and column visibility for free. Hand-rolling `RecordList` is what got us into the current state.

**Alternatives considered:**
- `List` with custom row layouts. Rejected because the column-style data display is the right model for a resource list with many similar rows.
- `OutlineGroup`. Rejected because the data is flat, not hierarchical.

### 4. TerminalLogView is a custom NSView-backed view (not pure SwiftUI)

The streaming log view uses an `NSTextView` wrapped in an `NSViewRepresentable`. The text storage is a custom `LogTextStorage` that appends lines incrementally and supports color rules per stream. The SwiftUI shell handles the toolbar (line numbers, search, copy), the gutter, and the "Jump to live" affordance.

**Why:** SwiftUI's `Text` and `TextEditor` both re-render the whole view when text changes, which is unacceptable for a streaming log that may receive hundreds of lines per second. `NSTextView` is the only view that can append incrementally with selection preservation.

**Alternatives considered:**
- `TextEditor` with an `@State String`. Rejected because it re-renders the whole buffer per append.
- A third-party terminal library. Rejected because we don't need full terminal emulation, just a streaming monospace log with line numbers and search.

### 5. Profile editor is presented as a sheet with a custom layout (not `Form`)

The editor is a sheet with a sticky header, a scrollable body of `SectionCard`s, and a sticky validation footer. The control layout inside each card is a custom `Grid` with label-left / control-right rows, replacing the `Form`/`.grouped` style.

**Why:** The current `Form { Section { ... } }.formStyle(.grouped)` is the most "ancient" thing in the UI. A custom card-based layout matches the rest of the app, supports proper validation, and gives us per-card customization that `Form` cannot (e.g. a slider with a live value label).

**Alternatives considered:**
- `Form { ... }.formStyle(.columns)`. Rejected because `.columns` is also a 2018 macOS look.
- SwiftUI `Inspector` panel. Considered, but the editor is destructive and modal-feeling, so a sheet is the right pattern. The Inspector pattern is reserved for the Inspect panel for individual containers.

### 6. Settings window is a sidebar split view (not a `TabView`)

The settings window uses the same `NavigationSplitView` pattern as the main window: a `List` of categories on the left, a `ScrollView` of `SectionCard`s on the right. The categories are stored as `SettingsPane` and the selection persists across opens.

**Why:** Tabs in macOS settings windows are fine but they hide the structure of the app's configuration. A sidebar makes the categories discoverable and consistent with the main workspace.

**Alternatives considered:**
- `TabView` with `tabViewStyle(.automatic)`. Rejected because that's the current approach and the user feedback was to change it.

### 7. Onboarding lives in a dedicated window, not a tab/sheet of the main window

`OnboardingWindow` is a separate `Window` scene (`@main` `App` body adds a new `Window` for onboarding). The window has a 720×520pt frame, an `unifiedCompact` title bar, and a multi-step `NavigationStack` for the wizard.

**Why:** Onboarding is a one-time experience; it should not take over the main window's chrome. A dedicated window is also the right pattern for a multi-step wizard that has its own back/forward navigation and progress indicator.

**Alternatives considered:**
- A sheet over the main window. Rejected because the main window is empty during onboarding and a sheet would feel like an error.
- A fullscreen window. Rejected because the user should be able to move/resize the onboarding window.

### 8. EmptyStateView is the only empty/loading surface

`SurfaceStateView` is renamed `EmptyStateView` and extended with `kind: EmptyStateKind` (noResults, noData, loading, error, unavailable, disabled). Every screen that can show a list, table, or section uses `EmptyStateView` for its empty/loading/error/unavailable/disabled state.

**Why:** The current mix of `SurfaceStateView` and bare `Text(...).foregroundStyle(.secondary)` is the source of most of the "feels unfinished" feeling in the screenshots. A single component enforces consistency.

**Alternatives considered:**
- Keep `SurfaceStateView` and add a separate `EmptyStateView`. Rejected because it would result in two near-identical components and the same drift.

### 9. Container lifecycle is a thin `ContainerService` on top of the existing `CommandRunService`

`ContainerService` is a new service class that wraps the existing `CommandRunService` and `StreamingProcessRunner` to expose `start`, `stop`, `restart`, `delete`, `inspect`, and `logs` as async/await calls. The service is observed by `AppState` so the resulting command is recorded in `CommandLogEntry` and the container table updates via the event bus.

**Why:** The UI layer should not be invoking `docker` directly; that's a service-layer concern. `ContainerService` is a natural seam that keeps the UI testable.

**Alternatives considered:**
- Add the methods to `BackendAggregationService`. Rejected because `BackendAggregationService` is for read-side aggregation; the new methods are write-side commands.

### 10. Toast notifications use a SwiftUI overlay, not NSUserNotification

The `ToastCenter` is a SwiftUI `Overlay` mounted at the top of the main window's `NavigationSplitView`. Toasts are an in-app notification layer, not a system notification; the system notification center is reserved for background events (which we don't have).

**Why:** A SwiftUI overlay is simpler, honors dark/light mode and dynamic type, and avoids asking the user for notification permissions.

**Alternatives considered:**
- `UserNotifications` framework. Rejected because we don't have background events to notify about and the permission prompt would feel unjustified.
- macOS Notification Center banners. Rejected for the same reason.

## Risks / Trade-offs

- **`NSViewControllerRepresentable` shim for the toolbar** → SwiftUI's `.toolbar` API has gaps (customization, some system styles). The shim could grow in scope. Mitigation: limit the shim to what SwiftUI cannot do, keep the rest in pure SwiftUI.
- **`Table` column customization on macOS 14** → SwiftUI `Table` column reordering/visibility requires `TableColumnCustomization` which is available on macOS 14+. The app's deployment target is already macOS 14 so this is fine. Mitigation: fall back to a fixed column set if the customization API has gaps on a particular macOS 14.x release; track in tests.
- **Streaming log performance** → the `NSTextView` approach should scale to thousands of lines, but we need to confirm via tests. Mitigation: benchmark with a 10K-line fixture and a 1000-line/sec append rate; the FIFO eviction at 5000 lines keeps the visible buffer bounded.
- **Onboarding first-run detection** → the `UserDefaults` flag is not a strong guarantee; a user clearing defaults would re-trigger onboarding. Mitigation: this is acceptable behavior; "Run onboarding again" exists in settings anyway.
- **Color contrast audit** → meeting WCAG 2.1 AA requires testing every text/surface pair. The automated test will fail the build if any pair fails. Mitigation: a deliberate token audit before merging; ship the test in CI from the start.
- **Risk: design system drift** → without strong enforcement, contributors will reach for raw `Color.blue` again. Mitigation: SwiftLint custom rule + a CI check that greps the view tree.
- **Risk: scope creep** → this is a 13-capability change. Mitigation: tasks are sequenced so Phase 1 (tokens, primitives, chrome) ships before Phase 2 (tables, editor, settings) before Phase 3 (container lifecycle, onboarding, polish). Each phase is independently shippable and demoable.
- **Trade-off: more files** → the view layer will grow from 5 files to ~25. Mitigation: clear folder structure (`DesignSystem/`, `Views/Chrome/`, `Views/Tables/`, `Views/Onboarding/`, `Views/Container/`, `Views/Settings/`).

## Migration Plan

- **Phase 0: Design system foundation** — `DesignSystem/` module, tokens, primitives (`SectionCard`, `MetricTile`, `StatusBanner`, `EmptyStateView`, `KeyValueGrid`, `IconBadge`, `StateDot`, `ToolbarActionButton`, `PrimaryButton`, `DestructiveButton`), `Icon` namespace, design-system tests. Switch one screen (Overview) to consume the new system end-to-end as the reference implementation. This phase is the only one that ships "behind a flag" (the new system is parallel-implemented; old views stay in place until their phase lands).
- **Phase 1: Chrome** — toolbar, sidebar, title bar, search, branding cleanup. Lands as a single visual change.
- **Phase 2: Tables** — `RecordList`/`RecordRow` removed, every resource screen uses `Table`. One screen per PR (Containers first, then Images, etc.).
- **Phase 3: Profile editor** — `ProfileEditorView` rewritten as a sheet of `SectionCard`s. The `Form`/`.grouped` usage disappears from the codebase.
- **Phase 4: Settings window** — `SettingsWindowView` rewritten as a `NavigationSplitView`. The `TabView`+`Form` disappears.
- **Phase 5: Terminal log** — `TerminalLogView` rewritten as an `NSTextView` wrapper.
- **Phase 6: Container lifecycle, inspect, logs** — `ContainerService` lands; new UI in the Containers screen.
- **Phase 7: Onboarding** — `OnboardingWindow` scene, three steps, first-run flag.
- **Phase 8: Menubar, motion, accessibility, empty-state pass** — final polish.
- **Phase 9: Snapshot tests, contrast audit, accessibility audit** — quality gate.

Each phase is independently shippable behind a feature flag (`UI.useDesignSystemV2`, `UI.useTable`, `UI.useNewProfileEditor`, `UI.useNewSettings`, `UI.useNewTerminal`, `UI.useContainerActions`, `UI.useOnboarding`). The flags default off in production until each phase is verified.

**Rollback:** Each phase flag can be turned off without affecting the others. The legacy `RecordList`/`RecordRow`/`Form` paths are removed only after their phase has been in production for at least one release.

## Open Questions

1. **Default density for tables.** `standard` (12pt row padding, body text) or `compact` (6pt row padding, subheadline)? Spec defaults to `standard`; the user can toggle.
2. **Maximum toast count.** Spec says 3; some users will want more. Resolve before Phase 8.
3. **Window size for onboarding.** Spec says 720×520; should be the same width as the settings window for visual consistency.
4. **Container logs in the Activity view vs. a dedicated Logs view.** Spec puts Logs in a dedicated view; some users will prefer an inline tab in the Containers screen. Resolve in Phase 6.
5. **Should the search field auto-focus on screen change?** Some users want it; some find it annoying. Default to off; user can press ⌘F.
6. **Confirm dialog copy.** "Delete container X?" — should it also list the image name and the time the container was created? Resolve in Phase 6.
7. **Should `Icon.brand` be a custom asset or the SF Symbol `shippingbox` filled variant?** Spec says custom; design mockup shows a custom mark. Decision: ship a custom mark in the asset catalog and reference it via `Image("BrandMark")` from `Icon.brand`.
