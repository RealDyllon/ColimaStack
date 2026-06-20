# iconography Specification

## Purpose
Resolve the iconography confusion in the current app, where the cube SF Symbol is used in five different variants to mean five different things. After this change there is a documented icon vocabulary with one symbol per concept: brand, runtime, profile, kubernetes, state, action.

## ADDED Requirements

### Requirement: Icon vocabulary is defined and enforced
The system SHALL expose a single `Icon` namespace (e.g. `Icon.brand`, `Icon.runtime.docker`, `Icon.runtime.containerd`, `Icon.runtime.apple`, `Icon.profile.running`, `Icon.profile.stopped`, `Icon.profile.transitioning`, `Icon.profile.error`, `Icon.kubernetes.enabled`, `Icon.kubernetes.disabled`, `Icon.action.start`, `Icon.action.stop`, `Icon.action.restart`, `Icon.action.delete`, `Icon.action.refresh`, `Icon.action.edit`, `Icon.action.reveal`, `Icon.action.copy`, `Icon.action.open`, `Icon.action.inspect`, `Icon.action.logs`, `Icon.action.terminal`, `Icon.action.wrench`) that maps each semantic concept to exactly one SF Symbol or asset. Screen code SHALL consume `Icon.*` accessors; raw `Image(systemName:)` literals SHALL NOT appear in screen code outside of the `Icon` namespace itself.

#### Scenario: No raw systemImage strings in screen code
- **WHEN** the screen code is searched for `Image(systemName:`
- **THEN** no matches are found in `ColimaStack/Views/**` other than the `Icon` namespace

#### Scenario: The cube means the brand
- **WHEN** the brand mark is rendered in the sidebar, the menu bar, and the about screen
- **THEN** the same symbol (`Icon.brand`) is used in all three places
- **AND** no screen uses a cube variant to mean a Colima profile or a Kubernetes cluster

### Requirement: The brand icon is distinct from the runtime icon
The system SHALL use `Icon.brand` (the ColimaStack wordmark/mark) as the brand mark, `Icon.runtime.docker`/`Icon.runtime.containerd`/etc. for the runtime identification, and `Icon.profile.*` for the profile state. A "cube" symbol SHALL appear in at most one of these three contexts in any given screen.

#### Scenario: Sidebar profile row uses a profile icon
- **WHEN** the sidebar profile roster is rendered
- **THEN** each row uses `Icon.profile.<state>` (not a cube variant) and a `StateDot` (not a cube) for state
- **AND** the brand mark at the top of the sidebar uses `Icon.brand`

#### Scenario: Kubernetes icon is consistent
- **WHEN** the Kubernetes section of the sidebar is rendered
- **THEN** the section header uses `Icon.section.kubernetes` (e.g. `hexagon.fill`) and the route icons use `Icon.kubernetes.enabled` for Cluster/Workloads/Services
- **AND** the icon used here is not a cube variant

### Requirement: Action icons are paired across surfaces
The Start, Stop, Restart, Delete, Refresh, Edit, and Reveal actions SHALL use the same SF Symbol across the toolbar, the contextual action bar, the menu bar, the profile editor, and the row context menus. A user who learns the icon in one surface SHALL recognize it in every other surface.

#### Scenario: Start icon is consistent
- **WHEN** the user sees Start in the toolbar, the contextual action bar, the menu bar, the profile editor, and the container row context menu
- **THEN** the same `play.fill` symbol is used in every surface
- **AND** the disabled state of the button is rendered with the system's standard disabled appearance (not a custom grey)

### Requirement: State dots are first-class
The system SHALL provide a `StateDot` component (already exists) that renders a colored dot for a `ProfileState` and SHALL use it in the sidebar profile roster, the profile roster screen rows, the menu bar status section, the overview headline, and the table cells. The dot is the only place a profile's state is communicated; the label is supplementary, not primary.

#### Scenario: State dot is the primary state indicator
- **WHEN** a profile is rendered in any list, table, or header
- **THEN** a `StateDot(state: profile.state)` is rendered as the first visual element
- **AND** the text label "Running" / "Stopped" / "Starting" is rendered next to the dot, not instead of it

### Requirement: Icons are size-correct
The system SHALL provide three icon sizes: `.iconControl` (16pt, used in toolbars, buttons, and table cell leading icons), `.iconRow` (20pt, used in sidebar and list rows), `.iconHero` (48pt, used in empty-state illustrations and the brand area). Each `Icon.*` accessor SHALL return a `View` that already applies the right size; screen code SHALL NOT call `.font(.system(size: ...))` on icons.

#### Scenario: Toolbar icons are 16pt
- **WHEN** an action icon is rendered in the toolbar
- **THEN** the icon is 16pt and uses the `.iconControl` size token
- **AND** the surrounding button padding matches the system `.borderless` button style

#### Scenario: Empty-state illustrations are 48pt
- **WHEN** an `EmptyStateView` renders its illustration
- **THEN** the symbol is 48pt and uses the `.iconHero` size token
- **AND** the symbol is tinted with the appropriate `status/*` color when the empty state is an error/warning/info kind
