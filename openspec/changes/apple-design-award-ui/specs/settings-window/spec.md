# settings-window Specification

## Purpose
Replace the `TabView`+`Form`/`.grouped` settings window in `WorkspaceScreens.swift` with a sidebar-style settings window that mirrors the main workspace's `NavigationSplitView` pattern, so the same design system is applied and the same keyboard and accessibility affordances work.

## ADDED Requirements

### Requirement: Settings window uses a sidebar split view
The system SHALL present the settings window as a `NavigationSplitView` with a `List` of categories in the sidebar and the corresponding pane on the right. The categories SHALL be: General, Kubernetes, Networking, Integrations, Advanced. The selection SHALL be bound to a `@State` `SettingsPane` so it persists across opens of the window.

#### Scenario: Settings window layout
- **WHEN** the user opens Settings
- **THEN** a window appears with a 200pt sidebar listing the five categories
- **AND** the right pane shows the General pane by default
- **AND** the window is 720×560pt with a min size of 600×480

#### Scenario: Selecting a category changes the pane
- **WHEN** the user clicks "Kubernetes" in the sidebar
- **THEN** the right pane is replaced with the Kubernetes pane
- **AND** the selection is preserved if the user closes and reopens Settings

### Requirement: Each pane is composed from SectionCards
Each pane SHALL be a `ScrollView` containing one or more `SectionCard`s with the same visual language as the main workspace. Controls SHALL be label-left / control-right rows within each card. There SHALL be no `Form` and no `.formStyle(.grouped)` anywhere in the settings window.

#### Scenario: General pane structure
- **WHEN** the General pane is rendered
- **THEN** it shows three cards: "Refresh" (auto-refresh toggle, frequency picker, live feeds toggle, streaming output toggle), "Selected" (selected profile, active section, refresh state), and "About" (version, build, acknowledgements)

#### Scenario: Kubernetes pane structure
- **WHEN** the Kubernetes pane is rendered
- **THEN** it shows a "Status" card (Enabled/Version/Context/Context name) and an "Actions" card (Enable/Disable, Edit Profile, Restart Profile)

#### Scenario: Networking pane structure
- **WHEN** the Networking pane is rendered
- **THEN** it shows a single "Endpoints" card with key/value rows for Docker context, Address, Socket, Mount type, and a copy affordance per row

#### Scenario: Integrations pane structure
- **WHEN** the Integrations pane is rendered
- **THEN** it shows a "Toolchain" card listing every detected `ToolCheck` using the redesigned `ToolRow` (icon, name, version, status, copy path) and a "Refresh" button at the bottom

#### Scenario: Advanced pane structure
- **WHEN** the Advanced pane is rendered
- **THEN** it shows two cards: "Profile actions" (Update Profile, Restart Profile, Reset Configuration with confirm) and "Diagnostics" (command history count, log capture state, diagnostics message count)

### Requirement: Settings window supports keyboard navigation
The user SHALL be able to navigate the entire Settings window without a mouse: ⌘1–⌘5 jumps to the matching category; ↑/↓ moves the selection in the sidebar; Tab moves between controls in the active pane; the standard Tab/Esc behavior SHALL apply to the popovers and dialogs.

#### Scenario: Cmd-3 jumps to Networking
- **WHEN** the user presses ⌘3 while the Settings window is focused
- **THEN** the Networking category is selected and the pane is replaced
- **AND** focus moves to the first control in the Networking pane

### Requirement: Destructive actions require explicit confirmation
The Reset Configuration action in the Advanced pane and any future destructive action SHALL open a confirmation dialog before running. The dialog SHALL explain what will be deleted, list the consequences, and SHALL have a destructive "Reset" button and a "Cancel" default button.

#### Scenario: Reset Configuration confirm
- **WHEN** the user clicks "Reset Configuration"
- **THEN** a dialog appears with the consequences and two buttons: Cancel (default) and Reset (destructive)
- **AND** pressing Escape or clicking Cancel closes the dialog without performing the reset
