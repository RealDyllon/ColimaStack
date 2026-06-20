# accessibility Specification

## Purpose
Make ColimaStack fully accessible: every control reachable via keyboard, every interactive element announced by VoiceOver, dynamic-type support, high-contrast color overrides, and reduced-motion fallback. The app SHALL meet WCAG 2.1 AA for contrast in both light and dark mode.

## ADDED Requirements

### Requirement: Full keyboard navigation
The system SHALL make every interactive control in the app reachable and operable using only the keyboard. Tab order SHALL follow visual source order within each card. The sidebar SHALL be focusable and SHALL support ↑/↓ navigation. Tables SHALL support arrow keys, shift-arrow extend, ⌘A select-all, ⌘C copy, ⌘F search, ⌘. cancel. Forms SHALL support Tab and Shift-Tab. The system SHALL provide discoverable keyboard shortcuts for the common actions (refresh, start, stop, restart, new profile, search, settings).

#### Scenario: All actions reachable without a mouse
- **WHEN** the user opens the app and uses only the keyboard
- **THEN** the user can refresh, switch profiles, switch sections, start/stop/restart a profile, create a new profile, open settings, open diagnostics, and view logs without ever using a mouse or trackpad

#### Scenario: Discoverable shortcuts
- **WHEN** the user opens the Help > Keyboard Shortcuts menu
- **THEN** a list of every shortcut in the app is shown, grouped by surface
- **AND** the list is also available via the standard macOS Help menu

### Requirement: VoiceOver labels for every interactive element
The system SHALL provide a `.accessibilityLabel` for every button, toggle, table row, sidebar row, card header, status indicator, and metric tile. The system SHALL provide `.accessibilityHint` for any action whose effect is not obvious from the label. The system SHALL group related elements with `.accessibilityElement(children: .combine)` where it makes the announcement clearer. Status indicators SHALL be announced as "State: running" not just "running".

#### Scenario: VoiceOver reads a status dot correctly
- **WHEN** VoiceOver focuses the StateDot of a profile row
- **THEN** VoiceOver announces "State: running" (not "green dot" or "circle")
- **AND** the row's accessibility label includes the profile name, state, runtime, and resource counts

#### Scenario: VoiceOver reads a metric tile
- **WHEN** VoiceOver focuses a `MetricTile` showing "12 GiB" for Memory
- **THEN** VoiceOver announces "Memory, 12 GiB" (label + value), not just "12 GiB"

### Requirement: Dynamic Type support
The system SHALL respect the user's preferred content size category and SHALL scale all text in the app proportionally. The system SHALL NOT clip or truncate text at any size category. Card layouts SHALL reflow to accommodate larger text (controls move to a stacked vertical layout below a threshold). Tables SHALL respect the user's preferred row height.

#### Scenario: Largest accessibility text size
- **WHEN** the user has the macOS "Larger Text" accessibility setting at the maximum
- **THEN** all text in the app is scaled to the maximum readable size without truncation
- **AND** metric tiles and card rows re-layout vertically so the larger text fits

### Requirement: High contrast support
The system SHALL respect the system "Increase contrast" setting and SHALL bump border opacity from 8% to 24% and text contrast from `text/primary` (90%) to 100% in that mode. The system SHALL also provide a high-contrast color override in the settings window for users who want a forced high-contrast theme regardless of the system setting.

#### Scenario: Increase contrast is on
- **WHEN** the system "Increase contrast" setting is on
- **THEN** card borders are visibly stronger
- **AND** secondary text reaches 7:1 contrast against the background
- **AND** status colors (success/warning/critical) all reach 4.5:1 against the background

### Requirement: WCAG 2.1 AA contrast in both color modes
The system SHALL meet WCAG 2.1 AA contrast for all text against its declared background in both light and dark mode. This SHALL be verified by an automated test that walks the design system tokens and asserts the contrast of every text role against every surface role it appears on.

#### Scenario: All token combinations pass contrast
- **WHEN** the contrast test runs
- **THEN** every (text role, surface role) pair used in the app passes 4.5:1 for body text and 3:1 for large text
- **AND** the test fails the build if any pair fails

### Requirement: Status changes are announced
The system SHALL use `AccessibilityNotification.Announcement` to announce significant state changes (profile started, profile stopped, command failed, container unhealthy) when VoiceOver is running. Announcements SHALL be terse ("Profile default started") and SHALL NOT spam — at most one announcement per 3 seconds.

#### Scenario: Profile start is announced
- **WHEN** a profile transitions to `.running` while VoiceOver is running
- **THEN** VoiceOver announces "Profile default started" within 1 second of the state change
- **AND** the announcement is debounced so a flurry of events does not produce a flurry of announcements

### Requirement: Reduced motion is honored
The system SHALL honor the system "Reduce motion" setting. All non-essential animations SHALL resolve to no-op or instant transitions. Progress indicators SHALL continue to animate. State color changes (e.g. StateDot turning green) SHALL be instant.

#### Scenario: Reduce motion is on
- **WHEN** the user has the system "Reduce motion" setting on
- **THEN** card transitions, hover highlights, and lifecycle flashes are instant
- **AND** spinners and the streaming cursor continue to animate
