# session-persistence

M1 asserted schema parity against a single static schema declaration, which cannot fail while there is only one declaration to compare. This change compares the schemas of two live containers built from two different store configurations.

## MODIFIED Requirements

### Requirement: Edition-neutral storage
Stored data SHALL be identical in shape across editions and across store configurations; no field SHALL exist solely to enforce or upsell editions, and no store configuration SHALL produce a different entity or attribute set from any other.

#### Scenario: Schema parity
- **WHEN** the schema is generated under Lite and Pro flags
- **THEN** the schemas SHALL be identical

#### Scenario: Two-configuration parity against live containers
- **WHEN** one store is opened in memory and another is opened on disk, and each live container's schema is read back
- **THEN** the entity names, attribute names, and attribute value types SHALL be identical between the two containers

#### Scenario: No edition-shaped field
- **WHEN** every attribute name in the live container schema is inspected
- **THEN** none SHALL name an edition, paywall, or upsell concept
