# workspace-chrome Specification

## Purpose
Replace the fake `Divider()`-delimited toolbar, the triple-titled window, and the inconsistent sidebar with native macOS 14+ chrome: a real `NSToolbar`, an `unifiedCompact` title bar, a single source of truth for the window title, and a sidebar that uses the system material and surfaces runtime health.

## ADDED Requirements

### Requirement: Window uses an NSToolbar via SwiftUI .toolbar
The system SHALL mount a native `NSToolbar` for the main window using SwiftUI `.toolbar` with `ToolbarItem` and `ToolbarItemGroup` placements. The toolbar SHALL contain, in order: refresh, separator, lifecycle `ControlGroup` (Start, Stop, Restart, Delete), separator, auto-refresh toggle, flexible space, secondary actions (Run Diagnostics, Settings, About). The toolbar SHALL honor the user's macOS toolbar preference (icons only, icons + text, text only) and SHALL be customizable via the standard "Customize Toolbar…" sheet.

#### Scenario: Lifecycle actions are grouped in a ControlGroup
- **WHEN** the toolbar is rendered
- **THEN** Start, Stop, Restart, and Delete appear inside a single `ControlGroup` rendered as a segmented control
- **AND** disabled state of the whole group is driven by `appState.selectedProfile == nil || appState.activeOperation != nil`

#### Scenario: Toolbar respects icon and label preferences
- **WHEN** the user selects "Icon and Text" in the Customize Toolbar sheet
- **THEN** all toolbar items render with both an SF Symbol and a text label
- **WHEN** the user selects "Icon Only"
- **THEN** all toolbar items render with only their SF Symbol
- **AND** the change is persisted per user by the system

### Requirement: Window title is shown once
The system SHALL set the window title to "ColimaStack" and SHALL NOT also display "ColimaStack" as a sidebar header or as a sidebar navigation title. The active profile name, if any, SHALL appear as a subtitle in the sidebar's brand area. The active section name SHALL appear in the title bar's secondary line.

#### Scenario: Window title does not repeat
- **WHEN** the main window is open on the Overview route
- **THEN** "ColimaStack" appears exactly once in the chrome (as the window title)
- **AND** the sidebar brand area shows the app mark + profile summary
- **AND** the title bar's secondary line shows "Overview"

#### Scenario: Sidebar navigation title is empty
- **WHEN** the `NavigationSplitView` sidebar is rendered
- **THEN** `navigationTitle` is empty so no extra title bar is injected into the sidebar

### Requirement: Sidebar uses the system material and a single profile roster
The system SHALL render the sidebar on the system sidebar material (`Sidebar`/`SidebarAccent` where supported). The sidebar SHALL contain, top-to-bottom: brand mark + tagline + profile status, route sections (Workspace, Runtime, Kubernetes, Support), a profile roster with a `+` button, and a runtime health footer. The profile roster SHALL be the single source of truth for the selected profile; the brand area's profile summary SHALL read from the same selection.

#### Scenario: Sidebar background uses system material
- **WHEN** the main window is rendered
- **THEN** the sidebar uses `.background(.sidebar)` or `Material.sidebar` and is NOT a custom gradient

#### Scenario: Active route shows an accent in the sidebar
- **WHEN** the user is on the "Containers" route
- **THEN** the Containers row in the sidebar has the system's sidebar accent (filled icon + accent text) and no other row has it

#### Scenario: Profile roster drives the selected profile
- **WHEN** the user taps a profile in the roster
- **THEN** the brand area's profile summary updates to the new selection
- **AND** the detail view refreshes for the new profile
- **WHEN** the user changes the selected profile via the menu bar
- **THEN** the roster's selection highlight follows

### Requirement: Searchable is positioned in the toolbar
The system SHALL place the `.searchable` modifier in the toolbar (`.toolbar` placement), not in a custom accessory view inside the detail. The search field's prompt SHALL be the scope label of the active route. Pressing `⌘F` SHALL focus the search field.

#### Scenario: Search field is in the toolbar
- **WHEN** the main window is rendered
- **THEN** the search field is positioned by the system in the toolbar trailing area
- **AND** no custom `TextField` styled as a search field appears in the detail header

#### Scenario: Cmd-F focuses search
- **WHEN** the user presses `⌘F` while the main window is focused
- **THEN** the search field gains first responder and its current value is selected

### Requirement: Main window has a minimum size and supports full-width layout
The main window SHALL set `defaultSize` to 1100×760 and `minSize` to 920×620. At 920pt the sidebar SHALL collapse to its icon rail automatically; at 1100pt+ the detail SHALL lay out as a wide layout with side-rail context where appropriate. The window SHALL support the standard fullscreen, zoom, and split-view behaviors.

#### Scenario: Narrow window collapses sidebar
- **WHEN** the user resizes the main window below the `.navigationSplitViewColumnWidth(min:)` threshold
- **THEN** the system automatically shows the icon-rail style for the sidebar
- **AND** the route list is still accessible via the sidebar's disclosure control

### Requirement: Window opens with a single window policy
The system SHALL set the macOS `WindowGroup` so that opening ColimaStack from the menu bar, the dock, or a deep link activates the existing window instead of creating a new one. `⌘N` SHALL open a new window. The `Window > Window` menu SHALL list open windows by their current route.

#### Scenario: Re-opening from the menu bar activates the existing window
- **WHEN** the main window is already open
- **AND** the user clicks the menu bar icon and chooses "Open Main Window" (or activates the app from the dock)
- **THEN** the existing window is brought to the front and made key
- **AND** no new window is created

#### Scenario: Cmd-N opens a new window
- **WHEN** the user presses ⌘N while the app is focused
- **THEN** a new main window opens
- **AND** the `Window > Window` menu lists both open windows by their current route
