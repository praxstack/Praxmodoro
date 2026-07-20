## ADDED Requirements

### Requirement: Sensitive data classification
The system SHALL classify task/action text, scratchpad thoughts, interruption notes, capacity/check-in answers, session events, and behavioral timestamps as sensitive user content and SHALL document every storage, retention, export, sync, diagnostic, and deletion path for each category.

#### Scenario: Data dictionary audit
- **WHEN** the V1 schema and privacy manifest are reviewed
- **THEN** every stored field maps to one named data category with purpose, default, retention, sync eligibility, export behavior, and deletion behavior

### Requirement: Local authoritative active state
The system SHALL keep the active session and timer state authoritative on the Mac and SHALL NOT depend on cloud sync or a network response for correctness.

#### Scenario: Network loss during focus
- **WHEN** network access disappears during an active session
- **THEN** start, pause, resume, check-in, break, thought parking, completion, recovery, and local persistence continue normally

### Requirement: Zero-network Lite baseline
The system SHALL originate no outbound application request during the Lite core loop while sync, integrations, diagnostics, license services, remote assets, and optional network features are disabled.

#### Scenario: Offline network capture
- **WHEN** a fresh Lite user runs a 30-minute local session with network features disabled under DNS/HTTP observation
- **THEN** the app originates no request and no UI capability waits for a network timeout

### Requirement: Bounded default retention
The system SHALL apply explicit bounded default retention and deterministic cleanup without silently retaining sensitive categories indefinitely.

#### Scenario: Default retention manifest
- **WHEN** default settings are inspected
- **THEN** active recovery is limited to 24 hours, task/action history to 30 days, capacity/check-in answers to the session, unresolved scratchpad to seven days after session, content-free aggregates to 90 days, and delivered/dismissed notifications to zero additional retention

#### Scenario: Retention cleanup
- **WHEN** the app launches or the daily cleanup becomes due
- **THEN** expired records are deleted by category and the privacy surface shows the last completed cleanup time and any category failure

### Requirement: Session-only capacity and check-ins by default
The system SHALL remove capacity and check-in answers at session end unless the user explicitly enables bounded private history for that category.

#### Scenario: Default completion cleanup
- **WHEN** a session completes with private capacity/check-in history disabled
- **THEN** the completed summary retains no raw capacity or check-in answer while factual content-free timing totals may remain

#### Scenario: Private history opt-in
- **WHEN** the user explicitly enables capacity/check-in history
- **THEN** the system explains its 30-day local retention and separate future sync choice before retaining later answers

### Requirement: Category-specific future sync consent
The system SHALL keep sync off by default and SHALL require an explicit category selection before the first upload; no unselected record or derived field may enter a sync payload.

#### Scenario: Completed-sessions-only sync
- **WHEN** a future Pro user enables only completed-session totals
- **THEN** the payload excludes task text, capacity, check-ins, scratchpad, interruption notes, live ticks, and hidden identifiers

#### Scenario: Sync unavailable or denied
- **WHEN** iCloud is unavailable, disabled by managed policy, or permission/eligibility fails
- **THEN** the system preserves local data and the complete Lite loop and reports the exact unavailable category without repeated coercive prompts

### Requirement: Privacy-safe notification lifecycle
The system SHALL request notification permission only after the user enables a notification-dependent feature and SHALL use content-minimized previews, event deduplication, dismissal, and quiet behavior.

#### Scenario: Permission timing
- **WHEN** a user has not enabled notifications
- **THEN** the app does not request notification permission during first launch or basic session start

#### Scenario: Default preview
- **WHEN** a phase or check-in notification appears with detailed previews disabled
- **THEN** it omits task text, capacity, check-in answers, interruption notes, and scratchpad content

#### Scenario: Event deduplication
- **WHEN** one due event produces both scheduling and wake callbacks
- **THEN** at most one system notification and one in-app prompt are emitted, and dismissing either suppresses repeats for that event

#### Scenario: System quiet settings
- **WHEN** macOS Focus or notification settings suppress an alert
- **THEN** the timer remains correct and the app neither requests Critical Alert entitlement nor bypasses system quiet behavior

### Requirement: Complete selectable export
The system SHALL disclose all exportable categories, let the user select them, and include exactly the selected records with no undisclosed identifiers or analytics fields.

#### Scenario: Minimal export
- **WHEN** the user exports completed-session totals only
- **THEN** the output contains only documented total fields and the export manifest names the schema version and selected category

#### Scenario: Export after downgrade
- **WHEN** paid entitlement has expired
- **THEN** all locally readable user categories remain exportable through Lite data-portability controls

### Requirement: Honest complete deletion
The system SHALL delete local task, action, scratchpad, check-in, capacity, session, event, aggregate, learned-suggestion, imported snapshot, and queued-notification data and SHALL initiate tombstones for every selected future sync category before claiming complete deletion.

#### Scenario: Successful local delete all
- **WHEN** the user confirms Delete All with sync disabled
- **THEN** all local category queries return empty, queued notifications are cancelled, encryption/license secrets unrelated to user content are handled by their own policy, and the app reports local deletion complete

#### Scenario: Partial synced deletion
- **WHEN** local deletion succeeds but a selected sync category cannot submit or confirm its tombstone
- **THEN** the system names the remaining category and retry state and does not report all copies deleted

#### Scenario: Exported files and backups
- **WHEN** deletion completes
- **THEN** the system explains that previously exported files and device backups are outside direct app deletion and provides the documented next steps without claiming otherwise

### Requirement: Content-free diagnostics
Diagnostics SHALL be off or separately opt-in, bounded in retention, and SHALL NOT contain raw task/action text, scratchpad, interruption notes, capacity, check-in answers, or stable cross-app advertising identifiers.

#### Scenario: Diagnostic event
- **WHEN** an opted-in recoverable engine error is recorded
- **THEN** the event contains only schema version, error class, coarse state kind, app/build metadata, and non-user-content correlation data

### Requirement: No surveillance or advertising
The system SHALL NOT collect screenshots, keystrokes, clipboard contents, microphone, camera, location, Health data, passive app/browser history, website content, fingerprinting, advertising identifiers, or data for sale/share.

#### Scenario: Permission and entitlement audit
- **WHEN** the app binary entitlements, usage descriptions, runtime permission requests, and network domains are inspected
- **THEN** none of the prohibited surveillance or advertising capabilities is present

### Requirement: Secret and migration hygiene
License evidence, sync credentials, and other secrets SHALL use Keychain or platform-secure storage, while persisted user schemas SHALL be versioned and migrated with failure recovery.

#### Scenario: Secret scan
- **WHEN** repository and runtime preference files are scanned
- **THEN** no production token, license secret, or sync credential is committed or stored in plain text preferences

#### Scenario: Migration failure
- **WHEN** a future schema migration cannot preserve a category
- **THEN** the app leaves the prior store recoverable, reports the affected category, and does not silently reset all user data
