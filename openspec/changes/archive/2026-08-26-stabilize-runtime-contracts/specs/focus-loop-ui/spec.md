## ADDED Requirements

### Requirement: Surfaces express routing intents through the model

Every SwiftUI surface SHALL request routing changes through a named `AppModel` method and SHALL NOT assign `AppModel.surface` directly; the property SHALL be read-only outside `AppModel` so the compiler enforces this boundary.

#### Scenario: Begin another session from review

- **WHEN** the user activates “Begin something new” on the review surface
- **THEN** the surface SHALL call `beginNextSession()`, the model SHALL route to initiate, and existing task text and preferences SHALL remain unchanged until the user edits or begins the next session

#### Scenario: Direct routing writes are structurally rejected

- **WHEN** the surface-boundary source test scans Swift files under `app/Sources/Surfaces/`
- **THEN** the test SHALL fail if any surface contains a direct `model.surface =` assignment
