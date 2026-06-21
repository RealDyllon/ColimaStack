# onboarding Specification

## Purpose
Build a first-run experience that turns a new user from "I just installed ColimaStack" into "I have a running Colima profile with a container" in three steps. Marks the **Deferred** design reconciliation items 48–50 (first-run welcome, missing-dependency handling, install/locate) as Implemented.

## ADDED Requirements

### Requirement: First-run window appears on launch
The system SHALL detect first-run state by checking a `UserDefaults` flag `colimastack.didCompleteOnboarding`. If the flag is absent (or `false`), the system SHALL present a dedicated `OnboardingWindow` instead of (or in addition to) the main window on first launch. The onboarding window SHALL have a 720×520pt frame, an `unifiedCompact` title bar, and a multi-step wizard.

#### Scenario: First launch with no Colima installed
- **WHEN** the user launches ColimaStack for the first time and `colima` is not on PATH
- **THEN** the onboarding window appears with the welcome step
- **AND** the main window does NOT appear behind it
- **AND** the onboarding flow advances to the dependency-check step

#### Scenario: Returning user
- **WHEN** the user has completed onboarding previously
- **THEN** the onboarding window does not appear on launch
- **AND** the main window appears directly

### Requirement: Welcome step explains what ColimaStack is
The first step SHALL show the brand mark, a one-sentence value proposition ("A focused workspace for your local Colima runtimes"), and a "Get Started" primary button. A "Skip onboarding" secondary link SHALL close the window and set the flag without taking any further action.

#### Scenario: Welcome step renders
- **WHEN** the welcome step is shown
- **THEN** the brand mark, the value proposition, and the "Get Started" button are visible
- **AND** the step honors the design system tokens
- **AND** the "Skip onboarding" link is reachable via Tab and via VoiceOver

### Requirement: Dependency check step
The second step SHALL run the existing `ToolCheck` suite (colima, docker, kubectl, limactl) and render a per-tool status row: green check for available (with version), red x for missing, yellow warning for errored. For each missing tool, the step SHALL show an "Install with Homebrew" button that pastes the appropriate `brew install …` command into a copy-to-clipboard popover with a "Copy" primary action. For `limactl`, the system SHALL also offer a "Locate manually…" button that opens a file picker.

#### Scenario: Missing colima
- **WHEN** the dependency check reports `colima` as missing
- **THEN** the row shows the missing state with an "Install with Homebrew" button
- **AND** clicking the button reveals the command `brew install colima` and a "Copy" action

#### Scenario: All tools present
- **WHEN** the dependency check reports all tools as available
- **THEN** the step shows a green success state with a "Continue" primary button
- **AND** the step auto-advances after 1 second

### Requirement: Profile creation step
The third step SHALL present a slimmed-down version of the profile editor (Name, Runtime, Resources, Kubernetes toggle) and SHALL create and start the new profile on "Create & Start". The step SHALL show a progress view with the active operation label, and SHALL advance to the success state when the profile reports `.running`.

#### Scenario: Create and start a profile
- **WHEN** the user fills in the name "dev", picks Docker, 4 vCPU, 8 GiB memory, and clicks "Create & Start"
- **THEN** a progress view appears with the active operation label ("Starting profile dev")
- **WHEN** the profile reaches `.running`
- **THEN** the success state appears with a "Open Workspace" primary button and a "View Logs" secondary button

#### Scenario: Create fails
- **WHEN** the profile creation or start fails
- **THEN** the step shows the error message in a `status/critical` banner with a "Retry" primary action
- **AND** the form data is preserved so the user does not have to re-enter it

### Requirement: Onboarding completion writes the flag and dismisses
When the user reaches the success state of the profile-creation step, the system SHALL set `colimastack.didCompleteOnboarding` to `true` in `UserDefaults` and SHALL dismiss the onboarding window. The main window SHALL open to the Overview screen for the newly-created profile.

#### Scenario: Successful onboarding
- **WHEN** the user clicks "Open Workspace" on the success step
- **THEN** the onboarding window closes
- **AND** the main window opens to Overview
- **AND** the next launch of the app goes directly to the main window

### Requirement: Onboarding is re-runnable from settings
The system SHALL expose a "Run onboarding again" button in the Advanced settings pane that clears the `colimastack.didCompleteOnboarding` flag and opens the onboarding window. The system SHALL also expose a "Re-run dependency check" button that re-runs only the dependency check step.

#### Scenario: Re-run from settings
- **WHEN** the user clicks "Run onboarding again" in Settings > Advanced
- **THEN** the onboarding window appears
- **AND** the main window is unchanged
