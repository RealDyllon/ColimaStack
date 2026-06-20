# menubar Specification

## Purpose
Polish the menu bar (`MenuBarExtra`) so it is the fastest way to check runtime health and trigger a one-click action: open the main window, see the selected profile, run a quick lifecycle action, jump straight to a port, and copy useful values. The current menu bar is too long and has redundant sections.

## ADDED Requirements

### Requirement: Menu bar label shows state with a single colored mark
The system SHALL render the `MenuBarExtra` label as a single colored SF Symbol for the selected profile's state (a filled dot for running, an outlined dot for stopped, a warning sign for degraded, a stop sign for broken, a question mark for unknown) using `Icon.profile.<state>`. The label SHALL NOT include text in the title bar; the status is communicated entirely by the symbol and its color. The accessibility label SHALL be the full status text ("ColimaStack: default, running").

#### Scenario: Menu bar icon reflects profile state
- **WHEN** the selected profile is `.running`
- **THEN** the menu bar shows a filled green dot
- **WHEN** the selected profile is `.stopped`
- **THEN** the menu bar shows an outlined grey dot
- **WHEN** the selected profile is `.degraded`
- **THEN** the menu bar shows a yellow warning sign

### Requirement: Menu bar structure is concise
The menu bar's drop-down SHALL be, in order: status header (compact: profile name, state, runtime, context), primary actions (Open Main Window, Refresh Now, Auto Refresh toggle), profile section (submenu listing every profile with a start/stop/restart quick action), runtime section (containers submenu with one-click "Open in browser" for published ports, volumes submenu, networks submenu), Kubernetes section (toggle Kubernetes, view node/pod/service counts, jump to view), diagnostics section (Run Checks, Open Activity, Copy Diagnostics), app section (Settings, About, Quit). Divider lines SHALL separate the top-level sections.

#### Scenario: Open menu bar with profile running
- **WHEN** the user clicks the menu bar icon
- **THEN** the menu opens to a concise status header followed by the five sections described above
- **AND** the entire menu fits in the standard 600pt menu height without scrolling

#### Scenario: One-click open a port
- **WHEN** the user expands the Containers submenu and right-clicks a running container
- **THEN** the submenu offers "Open localhost:3000" (and any other published ports) as the first items
- **AND** clicking the item opens the URL in the default browser without leaving the menu bar

### Requirement: Menu bar reflects live state
The menu bar's status header, profile list, and runtime counts SHALL update in real time as events arrive (via the existing `RuntimeEventBus`). The user SHALL NOT need to reopen the menu to see fresh data.

#### Scenario: Container starts and the menu bar updates
- **WHEN** a container starts while the menu bar is open
- **THEN** the Containers submenu's count updates immediately
- **AND** the "Open in browser" entry appears for any newly-published ports

### Requirement: Menu bar honors the app's accessibility settings
The menu bar SHALL be fully accessible: each menu item SHALL have a `.accessibilityLabel` and (where appropriate) a `.keyboardShortcut`. The "Quit ColimaStack" item SHALL have the `⌘Q` shortcut. The state header SHALL be read aloud as a single coherent announcement.

#### Scenario: VoiceOver reads the menu
- **WHEN** VoiceOver is focused on the menu bar
- **THEN** the status header is read as "ColimaStack, default, running, Docker, context colima"
- **AND** each menu item is announced with its label and shortcut
