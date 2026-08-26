# timer-engine

M1's module-isolation requirement used retired product-edition terminology. This change preserves the isolation contract while naming the actual one-product boundary.

## MODIFIED Requirements

### Requirement: Engine is UI-free and capability-registry-independent
The timer engine SHALL be a pure Swift module with no SwiftUI, AppKit, or network imports, and SHALL NOT import or consult the app-layer capability registry; timing behavior SHALL be identical regardless of app-layer feature-key configuration.

#### Scenario: Module isolation is testable
- **WHEN** the engine test target builds
- **THEN** it SHALL link only Foundation and the persistence protocol, and all scenarios above SHALL run headlessly with an injected clock

## RENAMED Requirements

- FROM: `### Requirement: Engine is UI-free and edition-free`
- TO: `### Requirement: Engine is UI-free and capability-registry-independent`
