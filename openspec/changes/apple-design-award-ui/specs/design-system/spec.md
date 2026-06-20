# design-system Specification

## Purpose
Define the visual design language, design tokens, and shared primitives that every screen in ColimaStack consumes. After this change, there is one source of truth for typography, color, surface elevation, spacing, radius, and motion; no view reaches for `Color(nsColor: .controlBackgroundColor)` or hard-codes a font size.

## ADDED Requirements

### Requirement: Design tokens are declared once and consumed everywhere
The system SHALL declare a `DesignSystem` namespace exposing typed tokens for typography (`TextStyle`), color roles (`ColorRole`), spacing (`Spacing`), radius (`Radius`), elevation (`Elevation`), and motion (`Motion`). Every view SHALL consume tokens via `DesignSystem.*` accessors; raw `Color`/`Font`/`CGFloat` literals SHALL NOT appear in screen code outside of `DesignSystem` itself.

#### Scenario: No raw colors in screen code
- **WHEN** the screen code is searched for `Color(`, `Color.`, and `nsColor:` outside of `DesignSystem/`
- **THEN** no matches are found in `ColimaStack/Views/**` other than the token definitions

#### Scenario: No raw font sizes in screen code
- **WHEN** the screen code is searched for `.font(.system(size:`
- **THEN** no matches are found outside of `DesignSystem/`

### Requirement: Typography scale is consistent across screens
The system SHALL provide a six-step typography scale: `display`, `title1`, `title2`, `title3`, `body`, `caption`, `code`, plus `mono`. Every title, subtitle, label, and value in the app SHALL bind to one of these styles. The `display` style SHALL be 28pt or smaller; the screen-title style SHALL be 22pt `title2` and SHALL be the largest text in any detail screen.

#### Scenario: Screen titles use the title2 style
- **WHEN** a `DetailScreenLayout` is rendered
- **THEN** the title text uses `DesignSystem.TextStyle.title2` and the icon glyph is at the same optical size

#### Scenario: Metric tile values use the title3 style
- **WHEN** a `MetricTile` is rendered
- **THEN** the value uses `DesignSystem.TextStyle.title3` and the label uses `caption`

### Requirement: Color roles are semantic, not appearance-based
The system SHALL expose color roles named for intent: `text/primary`, `text/secondary`, `text/tertiary`, `surface/canvas`, `surface/raised`, `surface/sunken`, `surface/inverse`, `border/subtle`, `border/strong`, `accent/primary`, `status/success`, `status/warning`, `status/critical`, `status/info`, `status/neutral`. Colors SHALL resolve through `Color(nsColor:)` for system materials and through `Color.init(...)` for brand colors; they SHALL automatically adapt to light and dark mode without per-view overrides.

#### Scenario: Status color tints the headline state only
- **WHEN** a `MetricTile` displays the profile `State` value
- **THEN** the value is rendered in `status/success` for `.running`, `status/info` for `.starting`/`.stopping`, `status/warning` for `.degraded`/`.broken`, and `text/primary` for `.stopped`/`.unknown`
- **AND** no other tile in the same screen uses a status color unless it is also a headline state

#### Scenario: Body text never uses status colors
- **WHEN** a `RecordRow` or `CommandEntryRow` displays a secondary field ("Up 2 hours", "True", "Succeeded")
- **THEN** that field is rendered in `text/secondary`, NOT in `status/success`/`status/info`

### Requirement: Surface elevation has three tiers
The system SHALL provide exactly three surface tiers: `canvas` (the window background), `raised` (one step up — used for cards, tiles, and the table), and `sunken` (one step down — used for table headers, code blocks, terminal log). No view SHALL stack more than two raised surfaces; a card inside a card is forbidden.

#### Scenario: Cards have a subtle hairline border
- **WHEN** a `SectionCard` is rendered on `canvas`
- **THEN** the card uses `surface/raised` background AND a 1px `border/subtle` outline
- **AND** the card's corner radius is `Radius.card` (12pt)

#### Scenario: Terminal log uses sunken surface
- **WHEN** a `TerminalLogView` is rendered
- **THEN** the view uses `surface/sunken` background and `text/primary` foreground

### Requirement: Spacing follows a four-point grid
The system SHALL provide spacing tokens `xs` (4pt), `sm` (8pt), `md` (16pt), `lg` (24pt), `xl` (32pt), `2xl` (48pt). Card padding SHALL be `md` (16pt) by default; section spacing inside a `ScrollView` SHALL be `lg` (24pt). Off-grid values SHALL NOT appear in screen code.

#### Scenario: Card padding is md
- **WHEN** a `SectionCard` is rendered
- **THEN** the card's internal padding is `DesignSystem.Spacing.md` (16pt) on all sides

#### Scenario: Section spacing is lg
- **WHEN** a `DetailScreenLayout` body is rendered
- **THEN** the spacing between sibling cards is `DesignSystem.Spacing.lg` (24pt)

### Requirement: Motion tokens declare duration and curve
The system SHALL provide motion tokens `fast` (150ms), `default` (220ms), `slow` (350ms), and curves `standard`, `emphasized`, `spring` (response 0.35, damping 0.85). Every animation in the app SHALL use one of these; ad-hoc `withAnimation(.easeInOut(duration: 0.3))` calls SHALL be replaced with token-based animations.

#### Scenario: Reduced motion disables non-essential animation
- **WHEN** the system "Reduce motion" accessibility setting is on
- **THEN** all `Motion.default` and `Motion.slow` animations resolve to `.none` (or `Motion.fast` for progress indicators)

### Requirement: Shared primitives consume tokens, never hard-code
The system SHALL provide these primitives, all consuming tokens: `SectionCard`, `MetricTile`, `StatusBanner`, `EmptyStateView` (replacing `SurfaceStateView`), `KeyValueGrid`, `IconBadge`, `StateDot`, `ToolbarActionButton`, `PrimaryButton`, `DestructiveButton`. The legacy `RecordList` and `RecordRow` components SHALL be removed in favor of native `Table`.

#### Scenario: Every primitive has a light and dark mode appearance
- **WHEN** a primitive is rendered in both light and dark mode
- **THEN** the primitive's contrast, surface, and text roles all pass WCAG AA against their declared background
