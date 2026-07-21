## ADDED Requirements

### Requirement: Capability-set gating
The system SHALL represent the complete Lite feature inventory as unconditional product behavior,
SHALL resolve validated paid grants into a separate set of optional product capabilities, and
SHALL gate both optional user-interface entry points and optional engine intents by capability
rather than scattering edition-name comparisons through features.

#### Scenario: Capability allowed
- **WHEN** validated evidence grants a requested optional capability, its adapter is implemented, its required runtime service or model is currently available, its authorization, platform, and distribution prerequisites are satisfied, and any applicable policy permits it
- **THEN** the system exposes the entry point and accepts the corresponding engine intent

#### Scenario: Capability unavailable
- **WHEN** the optional capability set does not contain a requested capability or an independent prerequisite is missing
- **THEN** the engine returns an explicit unavailable-capability result without mutating session state

#### Scenario: Required Lite behavior
- **WHEN** any required Lite feature is used
- **THEN** the system does not evaluate a paid capability check and preserves any OS-denial fallback

### Requirement: Lite contains the complete differentiated core
Lite SHALL include initiation, all four shipped timing presets, editable deterministic first-action help, focus/pause/resume, configurable/manual check-ins, detour recovery, breaks/re-entry, thought parking, low-cognitive-load mode, main/menu-bar/compact local surfaces, basic local history, notifications, accessibility, export/delete, and privacy controls.

#### Scenario: Lite feature matrix
- **WHEN** tests enumerate the required core capability identifiers for a Lite entitlement snapshot
- **THEN** every listed core identifier is present and no test requires a paid entitlement to complete the local focus loop

### Requirement: Pro adds convenience and depth without weakening Lite
The system SHALL retain every Lite capability while Pro is active. Pro MAY additionally grant saved advanced recipes/templates, richer local analytics and filters, automated exports, opt-in iCloud history/settings sync, EventKit/App Intents integrations, and optional on-device AI enhancement. Privileged blocking SHALL be absent from every edition until a separate add-on specification is approved.

#### Scenario: Pro entitlement
- **WHEN** a verified Pro transaction is active
- **THEN** the capability set is the union of Lite and approved Pro capabilities

#### Scenario: Pro service unavailable
- **WHEN** a Pro integration, sync service, or model is unavailable or permission is denied
- **THEN** the system preserves the complete Lite loop and exposes the deterministic/local fallback

### Requirement: Enterprise adds managed deployment without behavioral surveillance
Enterprise MAY grant signed offline licensing, deployment/update channels, managed privacy restrictions, approved defaults, retention/export policy, and configuration audit, but SHALL NOT grant manager access to personal task text, capacity, check-ins, scratchpad, session history, behavioral analytics, or productivity scores.

#### Scenario: Enterprise admin schema
- **WHEN** the managed configuration and audit schema is inspected
- **THEN** it contains only license, version, update, deployment, allowed privacy restriction, and configuration metadata and no personal behavior fields

#### Scenario: Managed privacy restriction
- **WHEN** an administrator disables outbound sync or diagnostics
- **THEN** the system enforces the restriction while personal coach cadence remains absent from managed configuration and private local content remains under user control

### Requirement: OS permission and distribution are independent
The system SHALL distinguish product entitlement from OS permission and distribution prerequisites.

#### Scenario: Entitled but permission denied
- **WHEN** Pro grants Calendar integration but the user denies EventKit access
- **THEN** the integration remains inactive, the app does not reprompt until the user retries, and all non-Calendar capabilities remain available

#### Scenario: Enterprise distribution unavailable
- **WHEN** Enterprise grants a managed capability but its signed-license or managed-deployment prerequisite is unavailable
- **THEN** the app reports the exact distribution prerequisite instead of treating Enterprise entitlement as proof of availability

### Requirement: Verifiable entitlement evidence
The system SHALL distinguish untrusted claims from validated grants, SHALL represent entitlement
snapshots with unconditional Lite features, optional granted/available capabilities, limits,
evidence type, verification status, issue/expiry metadata, every currently missing prerequisite, policy
provenance, and next reevaluation, and SHALL NOT treat a mutable Boolean or local preference as
license evidence.

Validated grants SHALL be opaque outside the verifier boundary and valid only while
`issuedAt <= verification-or-resolution-time < expiresAt`; resolution SHALL defensively reject a
future-issued or expired grant even after construction.

#### Scenario: Unverified paid evidence
- **WHEN** paid entitlement evidence cannot be verified
- **THEN** the system fails closed to Lite capabilities without deleting or hiding user data

#### Scenario: Static development evidence
- **WHEN** a debug or test build injects a static capability snapshot
- **THEN** the snapshot is visibly marked as development evidence and cannot be used as production license verification

#### Scenario: No production verifier in the first slice
- **WHEN** production resolution receives a paid claim before a StoreKit or signed-license verifier exists
- **THEN** the system reports verifier unavailable and resolves to Lite without exposing a paid entry point

### Requirement: Downgrade preserves active work and data
The system SHALL NOT interrupt an active session when paid evidence expiry is the only access
change, SHALL preserve only the session-bound policy capabilities captured by an opaque lease tied
to the committed session ID, start revision, complete entitlement snapshot, and commitment time
where their descriptor permits boundary downgrade. Transition logic SHALL compare the active
commit plus complete previous/next resolution contexts and SHALL require the next snapshot to be
the expired resolution of the same validated evidence (source, issue, expiry, and limits), rather
than a missing claim, logout, verifier failure, or caller-supplied reason. Authorization/platform/distribution/OS-safety/
enforced-privacy changes SHALL apply immediately (including when simultaneous with expiry), while
locally readable/exportable data remains available after new paid entry points revert to Lite.

#### Scenario: Pro expires during focus
- **WHEN** verified Pro evidence expires during an active session using a Pro timing recipe
- **THEN** the current session completes with its committed policy and new Pro-only sessions are unavailable after the next session boundary

#### Scenario: Offline downgrade
- **WHEN** a former Pro user launches offline with only Lite evidence
- **THEN** the full Lite loop works and previously created local data remains readable and exportable

### Requirement: Managed-policy precedence
Enterprise policy resolution SHALL use one exhaustive approved managed-input schema, SHALL return value
provenance, and SHALL apply OS safety restrictions first, enforced managed privacy policy second,
user choice third, recommended managed defaults fourth, and app defaults last. Enforced policy
MAY disable diagnostics or outbound sync but SHALL NOT enforce personal coach cadence or expose
personal behavior fields. Diagnostics and outbound sync application defaults SHALL be structurally
fixed off, and a recommendation SHALL NOT opt the user in.

#### Scenario: Personal cadence is not managed
- **WHEN** the managed configuration schema is enumerated
- **THEN** it contains no coach cadence field and cadence resolves only from user choice or the local app default

#### Scenario: Enforced privacy restriction
- **WHEN** an administrator enforces diagnostics disabled
- **THEN** neither a user preference nor paid entitlement can enable diagnostics

### Requirement: Edition changes are observable and testable
The system SHALL publish capability-snapshot changes independently from session snapshots and SHALL provide an edition-matrix contract test for every registered capability.

#### Scenario: Capability registry completeness
- **WHEN** a new product capability is added to the registry
- **THEN** tests require an explicit edition, authorization, platform eligibility, distribution, downgrade, data-access, and implementation-availability decision for it

#### Scenario: Capability change without session change
- **WHEN** entitlement evidence, policy, permission, platform, distribution, implementation, or runtime availability changes without a session transition
- **THEN** the app publishes the new capability snapshot independently while preserving the current session ID and revision
