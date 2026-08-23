# session-persistence

M1 asserted schema parity against a single static schema declaration, which cannot fail while there is only one declaration to compare. This change compares the schemas of two live containers built from two different store configurations.

## MODIFIED Requirements

### Requirement: Configuration-neutral storage
Stored data SHALL be identical in shape across store configurations; no field SHALL encode an edition, tier, license, paywall, or upsell concept, and no store configuration SHALL produce a different entity or attribute set from any other.

#### Scenario: Schema parity
- **WHEN** the schema is generated for the sole product configuration
- **THEN** it SHALL contain no feature-availability branch or tier-shaped attribute

#### Scenario: Two-configuration parity against live containers
- **WHEN** one store is opened in memory and another is opened on disk, and each live container's schema is read back
- **THEN** the entity names, attribute names, and attribute value types SHALL be identical between the two containers

#### Scenario: No tier-shaped field
- **WHEN** every attribute name in the live container schema is inspected
- **THEN** none SHALL name an edition, tier, license, paywall, or upsell concept

## RENAMED Requirements

- FROM: `### Requirement: Edition-neutral storage`
- TO: `### Requirement: Configuration-neutral storage`
