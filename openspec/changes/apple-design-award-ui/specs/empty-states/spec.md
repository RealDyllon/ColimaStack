# empty-states Specification

## Purpose
Replace the inconsistent empty/loading/error states across the app with a single `EmptyStateView` family that has first-class illustrations, primary/secondary actions, and recovery guidance. The current `SurfaceStateView` is rebranded and the bare `Text("No matching …").foregroundStyle(.secondary)` calls disappear.

## ADDED Requirements

### Requirement: EmptyStateView is a first-class surface
The system SHALL provide `EmptyStateView` as a single component that takes a `kind` (`.noResults`, `.noData`, `.loading`, `.error`, `.unavailable`, `.disabled`), a title, a message, an optional primary action, an optional secondary action, and an optional SF Symbol or asset illustration. The component SHALL render on `surface/canvas` with a 96pt illustration, a `.title3` title, a `.body` message, and stacked buttons. The existing `SurfaceStateView` SHALL be removed.

#### Scenario: Loading state
- **WHEN** data is loading for a screen
- **THEN** the screen body is replaced by an `EmptyStateView(kind: .loading, title: "Loading …", message: "Fetching data from colima")` with a `ProgressView` instead of an illustration
- **AND** the empty state honors the design system tokens (no hard-coded colors or fonts)

#### Scenario: No results state
- **WHEN** a search returns zero matches on a resource screen
- **THEN** the table is replaced by `EmptyStateView(kind: .noResults, title: "No matches", message: "Try a different search term or clear the filter", symbol: "magnifyingglass")` with a "Clear search" primary action

#### Scenario: No data state
- **WHEN** the resource list is empty and the user has not searched
- **THEN** the table is replaced by `EmptyStateView(kind: .noData, title: "No containers", message: "Pull or build an image and run a container to see it here.", symbol: "shippingbox")` with a "New Container" primary action

#### Scenario: Error state
- **WHEN** the data load fails with a known error
- **THEN** the table is replaced by `EmptyStateView(kind: .error, title: "Couldn't load containers", message: error.message, symbol: "exclamationmark.arrow.triangle.2.circlepath")` with a "Retry" primary action and a "View Diagnostics" secondary action

#### Scenario: Unavailable state
- **WHEN** the runtime is not available (e.g. Colima not installed, Docker context missing)
- **THEN** the table is replaced by `EmptyStateView(kind: .unavailable, title: "Docker isn't reachable", message: "Start the selected profile or check the diagnostics for more.", symbol: "shippingbox.circle")` with a "Start Profile" or "Refresh Diagnostics" primary action

#### Scenario: Disabled state
- **WHEN** a feature is disabled (e.g. Kubernetes not enabled on the selected profile)
- **THEN** the table is replaced by `EmptyStateView(kind: .disabled, title: "Kubernetes is disabled", message: "Enable Kubernetes on this profile to see cluster resources.", symbol: "hexagon")` with an "Enable Kubernetes" primary action

### Requirement: Inline empty states are the rule, not the exception
Every screen in the app that can show a list, a table, or a section SHALL render an `EmptyStateView` (or a chart/inline equivalent) when that surface is empty, loading, errored, unavailable, or disabled. A bare `Text("No matching …")` SHALL NOT appear in any screen. The CI check `openspec validate` and a SwiftLint custom rule SHALL flag any new `Text("No " + . + " found.")` literal.

#### Scenario: Containers empty state is rich
- **WHEN** the Containers table is empty
- **THEN** an `EmptyStateView` is rendered with a "Run a container" CTA that opens a "New Container" sheet (or a docs link if container creation is not yet implemented)
- **AND** the empty state is not just a single line of secondary text

#### Scenario: Workloads disabled state
- **WHEN** the Workloads screen is rendered for a profile without Kubernetes
- **THEN** the Pods card shows an `EmptyStateView(kind: .disabled, …)` with an "Enable Kubernetes" action that runs `appState.setKubernetes(enabled: true)`
- **AND** the Deployments card does not render an empty state until the user enables Kubernetes

### Requirement: EmptyStateView is animated in
Empty states SHALL animate in with a `Motion.default` cross-fade when replacing data. Loading states SHALL show a subtle shimmer (or `ProgressView` for the loading kind) on the illustration area. No layout shift SHALL occur between loading and loaded states; the empty state occupies the same vertical space as the eventual data.

#### Scenario: Smooth transition from loading to data
- **WHEN** data finishes loading
- **THEN** the empty state cross-fades to the table over `Motion.default` duration
- **AND** the table's first appearance does not cause the surrounding cards to jump
