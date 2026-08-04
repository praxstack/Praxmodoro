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
