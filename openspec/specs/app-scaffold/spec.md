# app-scaffold Specification

## Purpose
How the macOS application is generated, launched, and bounded. Covers reproducible project generation from `app/project.yml`, the documented build and test commands, lifecycle restore from persistence, the capability provenance registry that prevents withholding core ADHD support, the no-hidden-cloud guarantee, and build provenance.

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
The app SHALL restore the timer-engine session from persistence at launch and hand it to the UI before first render, so relaunch lands the user exactly where they were; with no persisted session it SHALL present the start path and nothing else.

#### Scenario: Relaunch into a running block
- **WHEN** the app is relaunched while a block is `running`
- **THEN** the focus surface SHALL be the first surface shown, with remaining time derived from canonical timestamps

#### Scenario: Fresh state lands on initiate
- **WHEN** the app launches with no persisted session
- **THEN** the initiate surface SHALL be shown

#### Scenario: Launch-time first-run assertion
- **WHEN** the app is launched against a fresh empty store and its interface is inspected
- **THEN** the start path controls SHALL be present, no running-session control SHALL be present, the begin control SHALL be disabled until a task is named, and no ambient companion surface SHALL have opened itself

### Requirement: No hidden cloud dependency
The app target SHALL make no network requests in this change; any future network capability SHALL arrive via its own spec with explicit opt-in.

#### Scenario: Launch is network-silent
- **WHEN** the app runs through a full loop under a network-observing test harness
- **THEN** zero outbound connections SHALL be observed

### Requirement: Capability provenance registry
The scaffold SHALL provide one injected registry of feature keys for architecture provenance; the sole product configuration SHALL resolve every feature key as available, and a hostile test fixture omitting a key SHALL fail startup validation while runtime lookup self-heals to available.

#### Scenario: One product grant is total
- **WHEN** the registry resolves every defined feature key
- **THEN** every key SHALL resolve available with no edition, tier, license, or upsell branch

#### Scenario: Hostile omission fails validation
- **WHEN** a test fixture omits any defined feature key
- **THEN** registry validation SHALL fail and runtime lookup SHALL still resolve the omitted key available

### Requirement: Deterministic build provenance
The scaffold SHALL stamp the app with version and git SHA, visible in the About surface, so every build's provenance is inspectable without product-tier vocabulary.

#### Scenario: About shows one-product provenance
- **WHEN** the About window opens
- **THEN** version and commit SHA SHALL be displayed, local-first identity SHALL remain visible, and no edition or tier label SHALL render
