# motion-feedback Specification

## Purpose
Add real motion, focus rings, hover states, success/failure micro-animations, and a non-blocking toast layer so the app feels alive and provides immediate feedback for every action. All motion honors the system "Reduce motion" setting.

## ADDED Requirements

### Requirement: Motion tokens drive every animation
The system SHALL consume `Motion.fast` (150ms), `Motion.default` (220ms), `Motion.slow` (350ms) and curves `Motion.standard`, `Motion.emphasized`, `Motion.spring` for every `withAnimation`, `transition`, and `animation` modifier. No raw `.easeInOut(duration: 0.3)` calls SHALL appear in screen code.

#### Scenario: Search appears with a fast animation
- **WHEN** a card transitions in on first render
- **THEN** the transition uses `Motion.default` with `Motion.standard` curve
- **AND** the transition is implemented via `.transition(.opacity.combined(with: .move(edge: .top)))` or similar token-driven transition

### Requirement: Reduced motion disables non-essential animation
The system SHALL observe `NSWorkspace.shared.accessibilityDisplayOptions.shouldReduceMotion` and SHALL replace `Motion.default` and `Motion.slow` with `.none` (and `Motion.fast` with `.linear(duration: 0.05)`) when the setting is on. Progress indicators SHALL continue to animate.

#### Scenario: Reduce motion is on
- **WHEN** the user has the system "Reduce motion" accessibility setting on
- **THEN** card transitions resolve to `.none`
- **AND** the spinner in the loading empty state still rotates
- **AND** status color changes (e.g. profile state dot turning green) are instant, not animated

### Requirement: Hover states appear on interactive elements
The system SHALL add a subtle background highlight (1% black in light mode, 5% white in dark mode) to interactive rows, list items, table rows, sidebar rows, and command buttons when hovered. The highlight SHALL appear with `Motion.fast` and SHALL disappear without animation when the cursor leaves.

#### Scenario: Hover a sidebar row
- **WHEN** the user hovers a sidebar route row
- **THEN** a subtle background highlight appears
- **WHEN** the cursor leaves
- **THEN** the highlight disappears immediately

### Requirement: Focus rings appear on keyboard focus
The system SHALL add a 2pt focus ring in `accent/primary` to every focusable control (buttons, table rows, sidebar rows, text fields, pickers) when focus is gained via the keyboard. Mouse focus SHALL NOT show a focus ring. The focus ring SHALL respect the system "Increase contrast" setting by using a thicker ring in that mode.

#### Scenario: Tab through the workspace
- **WHEN** the user tabs through the workspace with the keyboard
- **THEN** each focused control shows a focus ring
- **AND** the focus ring is the system blue (or the user's accent color), not a custom color

### Requirement: Lifecycle actions animate their result
When a Start/Stop/Restart/Delete/Update command succeeds, the affected profile or container row SHALL briefly flash a `status/success` background tint (220ms in, 600ms out) so the user gets an immediate visual confirmation. On failure, the row SHALL flash `status/critical`. On "command in progress" (e.g. `appState.activeOperation != nil` for that row), the row SHALL show an inline `ProgressView` in the trailing cell.

#### Scenario: Start profile succeeds
- **WHEN** the user starts a stopped profile
- **THEN** the profile row briefly flashes green as the state transitions to `.running`
- **AND** the StateDot animates from grey to green over `Motion.default`

#### Scenario: Start profile fails
- **WHEN** a Start command fails
- **THEN** the profile row flashes red
- **AND** a toast notification appears with the failure message and a "View Log" action

### Requirement: Toast notifications surface command results
The system SHALL provide a `ToastCenter` that shows transient notifications at the top-right of the main window for command results, warnings, and informational events. Toasts SHALL auto-dismiss after 5 seconds (configurable per-kind), SHALL be hoverable to pause the dismiss timer, SHALL stack vertically, and SHALL be announced to VoiceOver. There SHALL be at most 3 toasts visible at once; older toasts are evicted.

#### Scenario: Successful start shows a toast
- **WHEN** a Start command completes successfully
- **THEN** a toast appears at the top-right: "default started" with a checkmark icon and an "Open Activity" action
- **AND** the toast auto-dismisses after 5 seconds unless hovered

#### Scenario: Failure shows a persistent toast
- **WHEN** a command fails
- **THEN** a toast appears with the error message and a "View Log" primary action
- **AND** the toast does NOT auto-dismiss
- **AND** clicking the action jumps to the Activity screen with the failed command entry highlighted

### Requirement: Sheets and alerts use the system animations
The system SHALL use the system-provided sheet and alert presentations (no custom transitions) so the standard macOS motion is honored. Destructive confirmations SHALL use `.confirmationDialog` (action sheet) for the destructive case, not a custom modal.

#### Scenario: Delete profile uses confirmation dialog
- **WHEN** the user clicks "Delete" on a profile
- **THEN** a system confirmation dialog appears with the destructive "Delete" button styled in red
- **AND** the dialog animates in with the standard macOS sheet animation
