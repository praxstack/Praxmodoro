# app-scaffold

M1 asserted first-run behavior at the model layer. This change adds the launch-time assertion: what a real launch against a fresh store actually presents.

## MODIFIED Requirements

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

## ADDED Requirements

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

## REMOVED Requirements

### Requirement: Edition capability registry
**Reason**: Owner issue #34 replaced product editions with one complete product, so an edition-indexed requirement and its edition-specific scenarios are no longer valid.
**Migration**: Use `Capability provenance registry`; replace edition-indexed grants with one configured feature-key set whose validation fails on omissions while lookup cannot withhold behavior.

### Requirement: Deterministic versioning and provenance
**Reason**: The build still needs deterministic provenance, but the old requirement includes an edition stamp that issue #34 removed.
**Migration**: Use `Deterministic build provenance`; retain version and git SHA in About and remove the product-tier stamp and label.
