# data-tables Specification

## Purpose
Replace the custom `RecordList` / `RecordRow` views in every resource screen (Containers, Images, Volumes, Networks, Workloads, Deployments, Services) with native SwiftUI `Table`s. Every table supports column sort, row selection (single and shift-extend), keyboard navigation, copy-with-context, and a right-click context menu with first-class row actions (Start, Stop, Restart, Delete, Copy ID, Inspect, Logs).

## ADDED Requirements

### Requirement: Resource lists are rendered as Table
The system SHALL render Containers, Images, Volumes, Networks, Pods, Deployments, and Services as a SwiftUI `Table` with one column per resource attribute appropriate to the kind. Each table SHALL have an explicit `TableColumn` per attribute with a title, default width, optional `sortUsing` comparator, and an `accessibilityLabel`. The legacy `RecordList` and `RecordRow` types SHALL be removed.

#### Scenario: Containers table has named columns
- **WHEN** the Containers screen is rendered
- **THEN** a `Table` is shown with at least these columns: Name, Image, State, Status, Ports, Created
- **AND** the legacy `RecordList(columns:rows:)` constructor is no longer used anywhere in the codebase

#### Scenario: Pods table has namespace and node columns
- **WHEN** the Workloads screen is rendered
- **THEN** the Pods table has columns: Name, Namespace, Node, Phase, Ready, Restarts, Age
- **AND** the table is sortable by Name, Namespace, Phase, Ready, and Age

### Requirement: Tables support column sort
Every table column that is sortable SHALL set `sortUsing` to a comparator over the displayed value. Tapping a column header SHALL toggle the sort direction; the active sort column and direction SHALL be visible (system-provided arrow indicator). Default sort SHALL be by the first column, ascending.

#### Scenario: Tap-to-sort a column
- **WHEN** the user clicks the "State" column header on the Containers table
- **THEN** the table is sorted by State ascending and a sort indicator appears next to the header
- **WHEN** the user clicks the same header again
- **THEN** the sort direction toggles to descending

### Requirement: Tables support row selection and keyboard navigation
The system SHALL bind table selection to a `@Binding` of `Set<ResourceID>` and SHALL honor `TableSelectionBehavior(.selectable)` so that the user can select rows with the mouse, the keyboard (arrow keys, shift-arrow extend, ⌘-click toggle, ⌘A select all), and the standard find-bar (`/` to select by typing). The selected rows SHALL drive a contextual action bar that appears at the top of the table when the selection is non-empty.

#### Scenario: Arrow keys move selection
- **WHEN** the user presses the down-arrow key while a row in the Containers table is selected
- **THEN** the selection moves to the next row
- **AND** the table scrolls to keep the new selection visible

#### Scenario: Shift-click extends selection
- **WHEN** the user shift-clicks a row five positions below the current selection
- **THEN** all rows between the current selection and the clicked row are selected
- **AND** the contextual action bar appears with the appropriate actions for the selection set

#### Scenario: Cmd-A selects all visible rows
- **WHEN** the user presses ⌘A while a table is focused
- **THEN** every row currently visible in the table is selected
- **AND** the contextual action bar offers "Select All" if the user might want to extend the selection past the visible window

### Requirement: Tables provide a context menu with row actions
Every table row SHALL have a right-click context menu with actions appropriate to the resource type. For containers, the menu SHALL include Start, Stop, Restart, Delete (with confirmation), Copy ID, Copy Image, Copy Ports, Open in Browser (when a port binding exists), Inspect, and View Logs. Disabled actions SHALL be visibly disabled with a `.disabled` modifier and SHALL NOT be the first item.

#### Scenario: Right-click a container row
- **WHEN** the user right-clicks a running container row
- **THEN** the context menu shows: Start (disabled), Stop, Restart, Delete, ───, Copy ID, Copy Image, Copy Ports, Open in Browser (if ports), Inspect, View Logs

#### Scenario: Destructive action requires confirmation
- **WHEN** the user chooses "Delete" from a container row's context menu
- **THEN** a confirmation dialog appears with the container's name and a destructive "Delete" button
- **AND** the dialog has a Cancel button focused by default
- **AND** pressing Escape cancels

### Requirement: Tables have a contextual action bar for multi-selection
The system SHALL render a contextual action bar above the table when one or more rows are selected. The bar SHALL show "N selected" plus the most-common applicable actions (Start, Stop, Restart, Delete). Clicking an action SHALL apply to all selected rows; disabled actions SHALL be visibly disabled when none of the selected rows support the action.

#### Scenario: Three containers selected
- **WHEN** the user selects three running container rows
- **THEN** the contextual action bar appears with "3 selected" and Start (disabled), Stop, Restart, Delete actions
- **AND** clicking Stop opens a confirmation dialog before stopping all three

### Requirement: Tables support density toggle
Every table SHALL respect a `TableDensity` setting (`.standard`, `.compact`) stored in `AppState`. Switching density SHALL adjust row padding from 12pt to 6pt and font size from `.body` to `.subheadline` for row content. The default density SHALL be `.standard`.

#### Scenario: Toggle to compact density
- **WHEN** the user selects "View > Table Density > Compact"
- **THEN** all tables in the app immediately re-render with reduced row padding and smaller fonts
- **AND** the preference is persisted in `AppState` and survives relaunch
