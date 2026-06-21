# profile-editor Specification

## Purpose
Replace the `Form { Section { ... } }.formStyle(.grouped)` profile editor in `MainWindowView.swift` with a custom card-based editor that uses the same `SectionCard` primitive as the rest of the app, removes the macOS Mojave-era Form look, and is presented as a sheet that looks at home next to the rest of the workspace.

## ADDED Requirements

### Requirement: Profile editor is presented as a styled sheet
The system SHALL present `ProfileEditorView` as a sheet with `.presentationDetents([.large])`, `.presentationDragIndicator(.visible)`, and a `.presentationBackground(.regularMaterial)`. The sheet SHALL be 720pt wide and 760pt tall, with a sticky header (title + Cancel/Apply buttons) and a scrollable body of cards.

#### Scenario: Sheet appears with proper chrome
- **WHEN** the user clicks "Edit Profile" or "Create Profile"
- **THEN** a sheet appears with the system drag indicator, the title "Edit Profile" or "New Profile" in a 17pt semibold header
- **AND** the body shows the same `SectionCard` style used elsewhere in the app

### Requirement: Editor body is composed from SectionCards
The editor body SHALL be a `ScrollView { VStack { SectionCard { ... } ... } }` containing six cards: Profile, Resources, Kubernetes, Network, Mounts, Advanced. Each card SHALL have a title, optional subtitle, a leading SF Symbol, and a 16pt body padding. Within a card, controls SHALL be laid out using a label-left / control-right `Grid` for the most part, with custom row layouts only where the control demands it (mounts, k3s args).

#### Scenario: Editor is visually consistent with the rest of the app
- **WHEN** the profile editor sheet is rendered
- **THEN** the cards use `surface/raised` background and a `border/subtle` hairline
- **AND** the card corner radius is `Radius.card` (12pt)
- **AND** the card titles use `title3` weight semibold

### Requirement: Controls are first-class SwiftUI, not Form-derived
The system SHALL replace `Toggle("...", isOn: ...)` and `Picker("...", selection: ...)` (which are the `Form` style with the label as a leading column) with custom row layouts that use a body text label on the left and the control on the right. The system SHALL use `TextField` with the system rounded style, `Slider` (with a live value label) for numeric values where appropriate, `Stepper` only for small integer ranges, and `Picker` rendered as either a `Menu` or a `Picker(.segmented)` depending on the cardinality of the choice.

#### Scenario: Resources use sliders with live value labels
- **WHEN** the Resources card is rendered
- **THEN** CPU is a `Slider` from 1 to 32 with a "8 vCPU" value label
- **AND** Memory is a `Slider` from 1 to 128 with an "X GiB" value label
- **AND** Disk is a `Slider` from 10 to 2048 with an "X GiB" value label

#### Scenario: Network mode is a segmented picker
- **WHEN** the Network card is rendered
- **THEN** the Mode control is a `.segmented` Picker with "Shared" and "Bridged" options
- **AND** the Interface TextField is disabled when Mode is "Shared"

### Requirement: Mounts and K3s Args are inline editable lists
The Mounts card SHALL render each mount as a row with a "Local Path" `TextField`, a "VM Path" `TextField`, a "Writable" `Toggle`, and a "Remove" button. Adding a mount appends a new empty row. K3s Args and DNS Resolvers SHALL render as a list of `TextField`s each with a remove button and a single "Add" button. The "Add" affordance SHALL be a system `Image(systemName: "plus.circle.fill")` button in the section footer.

#### Scenario: Add a mount
- **WHEN** the user clicks "Add Mount"
- **THEN** a new mount row appears with empty local/VM paths and Writable on
- **AND** focus moves to the new row's Local Path field

#### Scenario: Remove a mount
- **WHEN** the user clicks the "Remove" button on a mount row
- **THEN** the row is removed from the configuration
- **AND** if the configuration had exactly one mount, a new empty mount row is added so the card never collapses to a degenerate state

### Requirement: Validation appears in a sticky footer
The validation summary SHALL live in a sticky footer at the bottom of the sheet (not as a free-floating orange block above the buttons, as today). The footer SHALL show a one-line summary when there are errors ("Resolve 2 issues before applying") and SHALL expand to a popover listing all errors when clicked. The Apply button SHALL be disabled when there is at least one error or an active operation is running.

#### Scenario: Errors block Apply
- **WHEN** the configuration has at least one validation error
- **THEN** the Apply button is disabled
- **AND** the footer shows "Resolve N issues before applying" in `status/warning` text
- **AND** clicking the footer text opens a popover listing each error

#### Scenario: No errors, no footer
- **WHEN** the configuration has zero validation errors and no active operation
- **THEN** the validation footer is empty and the Apply button is enabled

### Requirement: Apply triggers a confirm dialog for destructive changes
When the editor is editing an existing profile and the user has changed the `runtime`, `vmType`, or `diskGiB` (any of which would require the profile to be recreated), the Apply button SHALL open a confirmation dialog that explains the change will recreate the VM, lists the consequences, and requires explicit confirmation. Cancel keeps the dialog open with the form unchanged.

#### Scenario: Changing runtime prompts for VM recreation
- **WHEN** the user changes the `runtime` of an existing profile and clicks Apply
- **THEN** a confirmation dialog appears explaining that the VM will be recreated
- **AND** the dialog has a "Recreate" destructive button and a "Cancel" default button
- **AND** pressing Escape or clicking Cancel closes the dialog without applying

### Requirement: Editor is keyboard navigable
Every control in the editor SHALL be reachable via Tab, in source order. The Name `TextField` SHALL auto-focus when the editor opens. ⌘. or the Cancel button SHALL cancel. Return inside a `TextField` SHALL move to the next control. The system SHALL provide a "Revert to defaults" menu item in the editor's overflow menu that resets the configuration to `ProfileConfiguration.default`.

#### Scenario: Auto-focus the name field
- **WHEN** the editor sheet opens for a new profile
- **THEN** the Name field has first responder
- **AND** the user can immediately type the profile name without clicking

#### Scenario: Cancel with Cmd-period
- **WHEN** the user presses ⌘. while the editor is focused
- **THEN** the editor closes without applying changes
- **AND** no destructive operation runs
