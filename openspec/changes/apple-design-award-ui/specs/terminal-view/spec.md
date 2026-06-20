# terminal-view Specification

## Purpose
Replace the hand-rolled `TerminalLogView` (a `Text` inside a `ScrollView`) with a first-class monospace streaming log view that supports auto-scroll-to-bottom, "Jump to live" affordance, line numbers, copy-all, in-view search, color rules for stdout/stderr/error, and a streaming-aware text storage that does not re-render the entire buffer on each chunk.

## ADDED Requirements

### Requirement: TerminalLogView is a streaming-aware log view
The system SHALL provide a `TerminalLogView` that accepts an append-only `LogStream` of `LogLine` values (each with a `timestamp`, `stream` (`.stdout`/`.stderr`/`.system`/`.error`), and `text`). The view SHALL render up to a configurable maximum line count (default 5000) by FIFO-evicting the oldest line when the buffer exceeds the cap. New lines SHALL be appended incrementally without re-laying out existing lines.

#### Scenario: Stream appends new lines incrementally
- **WHEN** a new `LogLine` is appended to the stream
- **THEN** only the new line is rendered
- **AND** the existing lines retain their layout and selection state

#### Scenario: FIFO eviction keeps the buffer bounded
- **WHEN** the buffer exceeds 5000 lines
- **THEN** the oldest lines are dropped so the visible buffer stays at or below 5000 lines
- **AND** eviction is silent — no spinner, no flash

### Requirement: Monospace typography and ANSI-style color rules
The view SHALL render text in the system monospace font at the user's preferred size (default `.body`). Lines SHALL be colored by stream: `.stdout` in `text/primary`, `.stderr` in `status/warning`, `.system` in `text/secondary` (italic), `.error` in `status/critical`. Tab characters SHALL be expanded to 4 spaces.

#### Scenario: stderr lines are tinted warning
- **WHEN** a `.stderr` line is rendered
- **THEN** the line is colored `status/warning` and uses the system monospace font
- **AND** the line retains its color when scrolled

### Requirement: Auto-scroll-to-bottom with Jump to live affordance
By default, the view SHALL auto-scroll to the bottom when a new line arrives IF the user is already at (or within 24pt of) the bottom. If the user scrolls up to inspect history, auto-scroll SHALL pause and a "Jump to live" button SHALL appear at the bottom-right. Clicking the button SHALL resume auto-scroll and dismiss itself. `End` SHALL also jump to live.

#### Scenario: User scrolls up, auto-scroll pauses
- **WHEN** the user scrolls the log view upward more than 24pt
- **THEN** new lines continue to append but the view does not auto-scroll
- **AND** a "Jump to live" button appears at the bottom-right

#### Scenario: Jump to live resumes auto-scroll
- **WHEN** the user clicks "Jump to live"
- **THEN** the view scrolls to the bottom
- **AND** the button disappears
- **AND** subsequent new lines auto-scroll the view to the bottom

### Requirement: Line numbers, search, and copy
The view SHALL provide a left-gutter line-number column (toggleable via a button in the toolbar) that shows monotonically increasing line numbers from the start of the session. The view SHALL support an in-view search field (⌘F within the view) that highlights matching lines and shows a 1-of-N counter. The view SHALL support "Copy all" and "Copy visible" via a context menu and keyboard shortcuts (⌘A selects all visible, ⌘C copies the selection).

#### Scenario: Toggle line numbers
- **WHEN** the user clicks the line-number button in the terminal toolbar
- **THEN** the gutter appears with line numbers
- **WHEN** the user clicks the button again
- **THEN** the gutter collapses

#### Scenario: In-view search
- **WHEN** the user presses ⌘F while the log view is focused
- **THEN** a search field appears at the top of the view
- **WHEN** the user types "error"
- **THEN** all lines containing "error" are highlighted
- **AND** the counter shows "1 of N"
- **WHEN** the user presses Return
- **THEN** the next match is focused and scrolled into view

### Requirement: Log view supports theming via the design system
The view SHALL consume `surface/sunken` for its background and `text/primary` for default text. The line-number gutter SHALL use `text/tertiary`. Search highlights SHALL use `accent/primary` with 18% opacity. All colors SHALL automatically adapt to light and dark mode.

#### Scenario: Log view follows the system color scheme
- **WHEN** the system color scheme is dark
- **THEN** the log view background is `surface/sunken` resolved for dark mode
- **WHEN** the system color scheme is light
- **THEN** the log view background is `surface/sunken` resolved for light mode
- **AND** text is legible in both modes (WCAG 2.1 AA)

### Requirement: Log view is keyboard accessible
The view SHALL be focusable and SHALL honor standard macOS text behaviors: ⌘C copy, ⌘A select all (visible lines), ⌘F find, arrow keys scroll, Page Up/Page Down page-scroll, Home/End scroll to top/bottom. VoiceOver SHALL announce the line number and stream when the user navigates to a new line.

#### Scenario: Standard text shortcuts work
- **WHEN** the user presses ⌘C while text is selected in the log view
- **THEN** the selected text is copied to the clipboard
- **AND** the rest of the standard NSTextView shortcuts (⌘A, ⌘F, arrow keys, Page Up/Down, Home/End) work as expected

#### Scenario: VoiceOver announces line context
- **WHEN** VoiceOver navigates to a new line in the log view
- **THEN** VoiceOver announces the line number and the stream (e.g. "Line 42, stderr, error: connection refused")
