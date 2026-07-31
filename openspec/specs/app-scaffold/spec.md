# app-scaffold Specification

## Purpose
TBD - created by archiving change add-app-scaffold-core-loop. Update Purpose after archive.
## Requirements
### Requirement: Reproducible project generation
The repository SHALL contain an XcodeGen `project.yml` under `app/` that deterministically generates the Xcode project with an app target, a unit-test target, and a UI-test target for macOS 26+, Swift 6.3.

#### Scenario: Clean clone builds
- **WHEN** a clean clone runs the documented generate-and-build commands
- **THEN** the app target SHALL build with zero warnings-as-errors violations and both test targets SHALL run

#### Scenario: Generated project is not hand-edited
- **WHEN** the generated `.xcodeproj` differs from a fresh `xcodegen generate` output
- **THEN** the verification script SHALL fail, directing edits to `project.yml`

### Requirement: Documented build and test commands
README SHALL document the exact commands to generate, build, test, and run the app, and those commands SHALL be the same ones CI and agents use.

#### Scenario: Commands are executable as documented
- **WHEN** each documented command is run verbatim from the repo root
- **THEN** each SHALL exit zero on a healthy tree

### Requirement: App lifecycle restores state
The app SHALL restore the timer-engine session from persistence at launch and hand it to the UI before first render, so relaunch lands the user exactly where they were.

#### Scenario: Relaunch into a running block
- **WHEN** the app is relaunched while a block is `running`
- **THEN** the focus surface SHALL be the first surface shown, with remaining time derived from canonical timestamps

#### Scenario: Fresh state lands on initiate
- **WHEN** the app launches with no persisted session
- **THEN** the initiate surface SHALL be shown

### Requirement: Edition capability registry
The scaffold SHALL provide a capability registry resolving feature keys against the active edition (Lite/Pro/Enterprise), injected at app start; the Lite grant SHALL include every capability in this change, and core accessibility and ADHD-support behavior SHALL be structurally impossible to gate off Lite.

#### Scenario: Lite grant is total for this change
- **WHEN** the registry resolves every feature key introduced by this change under Lite
- **THEN** every key SHALL resolve to available

#### Scenario: Core support cannot be paywalled
- **WHEN** a registry configuration attempts to mark initiation help, check-ins, adaptive breaks, or accessibility modes as non-Lite
- **THEN** registry validation SHALL fail at startup in debug and the key SHALL resolve as available in release

### Requirement: No hidden cloud dependency
The app target SHALL make no network requests in this change; any future network capability SHALL arrive via its own spec with explicit opt-in.

#### Scenario: Launch is network-silent
- **WHEN** the app runs through a full loop under a network-observing test harness
- **THEN** zero outbound connections SHALL be observed

### Requirement: Deterministic versioning and provenance
The scaffold SHALL stamp the app with version, git SHA, and edition, visible in the About surface, so every build's provenance is inspectable.

#### Scenario: About shows provenance
- **WHEN** the About window opens
- **THEN** version, commit SHA, and edition SHALL be displayed

