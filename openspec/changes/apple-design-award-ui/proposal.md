## Why

ColimaStack today is a competent macOS control plane for Colima, but its UI reads as an engineer-built dashboard rather than a polished Mac app. The shipped interface has a fake `Divider`-delimited toolbar that mimics a real `NSToolbar`, a `Form { ... }.formStyle(.grouped)` profile editor and settings window that look like System Preferences from macOS Mojave, custom `RecordList`/`RecordRow` views where SwiftUI `Table` would be native, and status colors that shout ("Running", "Up 2 hours", "True", "Succeeded" all in saturated green). There is a real, beautiful set of design mockups in `design/mockups/` that the implementation never converged on. Container lifecycle actions, container inspect, per-container logs, and a first-run welcome were all marked **Deferred** in the design reconciliation table.

This change unifies every screen behind one design system, replaces the form-era chrome with native macOS 14+ patterns, adds the deferred first-class workflows, and brings the implementation up to the standard of the existing design mockups so the app is a credible Apple Design Award submission.

## What Changes

- **Introduce a real design system** (`DesignSystem`): typography scale, semantic color roles, surface elevation, spacing, radius, motion tokens. No more ad-hoc `Color(nsColor: .controlBackgroundColor)` scattered through the views. Every screen consumes tokens.
- **Rebuild the window chrome**: native `NSToolbar` with proper `ToolbarItem` placements, `ControlGroup` for the lifecycle actions (Start/Stop/Restart/Delete), `unifiedCompact` title bar, `.searchable` placed correctly, and a single source of truth for the window title. Remove the brand-name triplication.
- **Rebuild the sidebar**: clear profile roster as the only source of truth for selection state, branded header that does not duplicate the window title, proper `NavigationSplitView` styling, and a status footer that summarizes runtime health.
- **Replace `RecordList`/`RecordRow` with `Table`** across Containers, Images, Volumes, Networks, Workloads, Deployments, and Services. Adds column sort, row selection, copy-with-context, keyboard navigation, and right-click actions for free.
- **Replace the `Form`-based profile editor** with a custom card layout using the same `SectionCard` primitive as the rest of the app. Six `Section`s collapsed into a single scrollable page of cards with a sticky validation footer.
- **Replace the `TabView`+`Form` settings window** with a sidebar-style settings window that matches the main workspace. The five categories (General, Kubernetes, Networking, Integrations, Advanced) become a `List` of sections in the sidebar; the detail is composed from `SectionCard`s.
- **Build a first-class `TerminalLogView`**: monospace, line-number toggle, auto-scroll-to-bottom with "Jump to live" affordance, copy-all, search, color rules for stdout/stderr/error, and a streaming-aware text storage that does not re-render the whole buffer on each chunk.
- **Unify empty/loading/error surfaces**: every screen uses `SurfaceStateView` (or a new `EmptyStateView` family with first-class inline action buttons, illustrations, and recovery guidance). The bare `Text("No matching …").foregroundStyle(.secondary)` calls go away.
- **Resolve the iconography mess**: brand cube is only the brand, runtime/profile gets a distinct icon, Kubernetes gets `hexagon`, state uses dots/badges. No more cube variants meaning different things.
- **Add real container lifecycle actions**: per-row Start/Stop/Restart/Delete with confirmation for destructive actions, plus a per-container Inspect panel and Logs view.
- **Add a first-run onboarding flow**: welcome screen, dependency check, install/locate guidance, "create your first profile" walkthrough. Marks **Deferred** items 48–50 as Implemented.
- **Add proper motion and feedback**: smooth section-card transitions, focus rings, hover states on rows and buttons, success/failure micro-animations on lifecycle actions, and a non-blocking toast layer for command results.
- **Harden accessibility**: full keyboard navigation across all tables and forms, VoiceOver labels for every state indicator, dynamic-type support, high-contrast color overrides, and reduced-motion fallback.
- **Polish the menu bar**: rename "Selected Profile" to use a profile status dot, collapse the duplicate "Open ColimaStack" / dock-click behavior, and surface quick container actions in the containers submenu.
- **Tighten visual hierarchy**: tame the saturated-green status color, drop the 28pt screen title to 22pt, give every screen a consistent title-bar treatment, and add a real sidebar accent for the active route.

## Capabilities

### New Capabilities

- `design-system`: Typography, color roles, surface elevation, spacing/radius/motion tokens, and the shared primitives (`SectionCard`, `MetricTile`, `StatusBanner`, `EmptyStateView`, `KeyValueGrid`, `IconBadge`) that consume them.
- `workspace-chrome`: Native `NSToolbar`, `NavigationSplitView` chrome, title bar, sidebar, search, and brand-area styling.
- `data-tables`: `Table`-based resource views with column sort, row selection, keyboard navigation, copy-with-context, context-menu actions, and density toggle.
- `profile-editor`: Card-based profile editor replacing the `Form`/`.grouped` implementation, with a sticky validation footer and consistent controls.
- `settings-window`: Sidebar-style settings window replacing the `TabView`+`Form` implementation.
- `terminal-view`: Monospace streaming log view with auto-scroll, line numbers, search, copy, and color rules.
- `empty-states`: First-class empty/loading/error surfaces with illustrations, primary actions, and recovery guidance; used everywhere a list, table, or section can be empty.
- `iconography`: A documented icon vocabulary (brand, runtime, profile, kubernetes, state, action) with one symbol per concept.
- `motion-feedback`: Transitions, focus rings, hover states, success/failure micro-animations, and toast notifications.
- `accessibility`: Keyboard navigation, VoiceOver labels, dynamic type, high-contrast and reduced-motion support.
- `menubar`: Menu bar layout, ordering, status presentation, and per-profile submenu.
- `onboarding`: First-run welcome, dependency discovery, profile creation walkthrough.
- `container-lifecycle`: Per-container Start/Stop/Restart/Delete, Inspect panel, and Logs view.

### Modified Capabilities

None. None of the existing spec requirements (event bus, file watcher, kubernetes watch, docker event socket, streaming process runner) change at the requirement level as a result of this UI work. Their implementations may be touched to surface new UI affordances, but the requirements are stable.

## Impact

- **Code:** `ColimaStack/Views/*` is rewritten in part. `WorkspaceComponents.swift` is split into a `DesignSystem` module and per-feature component files. `MainWindowView.swift` and `WorkspaceScreens.swift` lose their `Form` usages. A new `Tables/`, `Onboarding/`, `Container/`, and `Chrome/` view folder is added.
- **Models:** Existing resource models gain `Identifiable`+`Hashable` conformance where missing so they can back `Table`. Container resource adds lifecycle affordances and inspect payload.
- **Services:** No service-layer behavior change. `BackendAggregationService` may expose a "destructive container operation" entry point used by the new container-lifecycle UI.
- **Tests:** UI tests are extended for keyboard navigation, VoiceOver labels, table sort, and onboarding flow. Snapshot tests for the design system tokens and for the empty-state gallery are added.
- **Dependencies:** None added. SwiftUI `Table` (macOS 12+) and `NavigationSplitView` (macOS 13+) are already available. The app's deployment target is already macOS 14+.
- **Risk:** Highest risk is the toolbar/`NSToolbar` migration; SwiftUI's `.toolbar` API is uneven for some custom placements and may require an `NSViewControllerRepresentable` shim. Mitigated by the design phase.
- **Out of scope:** Any change to the underlying CLI/runtime behavior, event-bus architecture, file format, or distribution model. The app's contract with Colima/Docker/kubectl is unchanged.
