## ADDED Requirements

### Requirement: Non-clinical supportive positioning
The system SHALL describe coaching as optional focus support and SHALL NOT diagnose, treat, prevent, score symptoms, infer mental-health risk, or substitute for professional care.

#### Scenario: [AHC-S001] Coach explanation
- **WHEN** the user opens the coach explanation or privacy surface
- **THEN** the system states that suggestions are non-clinical, based on explicit inputs/session events, and fully user-steerable

### Requirement: Capacity is optional and uninferred
The system SHALL default capacity to unspecified, SHALL store no capacity value without an explicit selection, and SHALL make no capacity-derived suggestion when it is unspecified.

#### Scenario: [AHC-S002] Start without capacity
- **WHEN** the user starts a session without selecting capacity
- **THEN** the session stores `nil`, displays “Not specified” where relevant, and creates no capacity-derived suggestion or analytic

#### Scenario: [AHC-S003] Clear capacity
- **WHEN** the user clears a previously selected capacity before start
- **THEN** the prepared session returns to unspecified and removes the capacity input from suggestion reasons

### Requirement: Editable deterministic first action
The system SHALL offer an editable tiny first action and SHALL always provide deterministic/manual help without requiring an AI model.

#### Scenario: [AHC-S004] Manual first action
- **WHEN** the user types a first action directly
- **THEN** the system preserves the user text and allows the session to start without generation

#### Scenario: [AHC-S005] Deterministic breakdown
- **WHEN** the user requests a smaller action while AI is disabled, unavailable, or fails
- **THEN** the system offers an editable deterministic prompt or blank manual field without losing task text or blocking start

#### Scenario: [AHC-S006] AI suggestion acceptance
- **WHEN** a future on-device model suggests a first action
- **THEN** the system persists it only after the user accepts or edits the suggestion

### Requirement: Explicit-input adaptation only
The system SHALL derive coaching suggestions only from explicit task/session inputs, user choices, and scheduled events and SHALL NOT inspect app activity, websites, screenshots, keystrokes, clipboard, microphone, camera, location, Health data, or physiological signals.

#### Scenario: [AHC-S007] Detour suggestion reason
- **WHEN** the user reports a detour and requests help
- **THEN** the system identifies the reported detour and current session policy as its reasons without claiming passive drift detection

### Requirement: User-steerable check-ins
The system SHALL make check-ins optional, configurable, manually triggerable, dismissible, and semantically selectable; the deterministic V1 default is every 15 minutes, configurable to manual-only or a 5-to-120-minute interval, and is not presented as a medical or optimal cadence.

#### Scenario: [AHC-S008] Due check-in choices
- **WHEN** a check-in becomes due
- **THEN** the system offers Continue, Make Smaller, Detour, Break, Skip, and Dismiss with programmatically exposed selection/action state

#### Scenario: [AHC-S009] Ignored check-in
- **WHEN** a check-in receives no answer or is dismissed
- **THEN** the system creates no failure, streak loss, diagnosis, escalating prompt, negative copy, or duplicate event notification

#### Scenario: [AHC-S010] Cadence changes during session
- **WHEN** the user changes cadence or hides scheduled coach prompts while a session is active
- **THEN** the setting takes effect for future prompts without restarting or damaging the active session

### Requirement: Gentle detour recovery
The system SHALL preserve task context when a detour is reported and SHALL let the user resume, shrink the action, park the detour, take a break, or intentionally stop.

#### Scenario: [AHC-S011] Park and return
- **WHEN** the user records a detour note and chooses return
- **THEN** the system parks the note, restores the prior editable first action, and resumes from the committed session state

#### Scenario: [AHC-S012] Make smaller
- **WHEN** the user chooses Make Smaller
- **THEN** the system pauses phase progression until the user accepts or edits a smaller action and then explicitly resumes

### Requirement: Explainable and optional breaks
The system SHALL explain which explicit inputs produced a break suggestion and SHALL allow another break, quiet/no-instruction mode, disabling future suggestions, skipping, or ending early without penalty.

#### Scenario: [AHC-S013] Suggested break
- **WHEN** the user explicitly reports restless capacity during a long focus phase and requests a break suggestion
- **THEN** the system cites those inputs, presents at least one alternative including quiet mode, and makes the suggestion dismissible

#### Scenario: [AHC-S014] End break early
- **WHEN** the user ends a break before its optional duration
- **THEN** the system restores the prior task and editable next action without a negative outcome or forced remaining time

### Requirement: Re-entry preserves orientation
The system SHALL restore the prior task, accepted first action, parked thoughts, and relevant session context when returning from a check-in or break.

#### Scenario: [AHC-S015] Return from break
- **WHEN** a break completes or is ended
- **THEN** the system presents the prior task and editable next action before focus resumes

### Requirement: Low-cognitive-load focus mode
The system SHALL provide a Lite low-cognitive-load mode independent of visual accessibility settings.

#### Scenario: [AHC-S016] Mode enabled
- **WHEN** low-cognitive-load mode is enabled
- **THEN** the focus surface shows only task, next action, optional timer, primary timer control, thought capture, and check-in/break escape hatch while hiding analytics, ambient animation, coach history, and upgrade UI

#### Scenario: [AHC-S017] Relaunch in low-cognitive-load mode
- **WHEN** the app relaunches during an active session with the mode enabled
- **THEN** the reduced information hierarchy is restored without requiring reconfiguration

### Requirement: Descriptive evidence-aware review
The system SHALL present counts and observations without causal, diagnostic, moral, or comparative language and SHALL never change defaults from analytics without separate confirmation.

#### Scenario: [AHC-S018] Sparse observations
- **WHEN** fewer than five relevant observations across three distinct days exist
- **THEN** the review shows counts and denominators only and makes no pattern recommendation

#### Scenario: [AHC-S019] Eligible descriptive pattern
- **WHEN** at least five relevant observations across three distinct days support a pattern
- **THEN** the system states the observation count, labels uncertainty, and offers any setting change as an explicit confirmable choice

### Requirement: No punitive or coercive design
The system SHALL NOT use streak loss, guilt, urgency, forced breaks, mandatory accounts, red failure states, escalating reminders, or completion penalties for detours, skipped check-ins, low capacity, or early stopping.

#### Scenario: [AHC-S020] Intentional early stop
- **WHEN** the user stops a session early
- **THEN** the system records the factual duration and optional note without failure language, lost points, or an upgrade prompt

### Requirement: No commerce in vulnerable flow states
The system SHALL NOT show an upgrade interstitial or blocking purchase prompt during initiation help, focus, check-in, detour, break, re-entry, low-capacity, or review-recovery states.

#### Scenario: [AHC-S021] Pro capability requested during focus
- **WHEN** a Lite user reaches a Pro-only entry point while an active focus-loop state exists
- **THEN** the system preserves the session, offers a non-blocking informational route for later, and returns to the current state without a purchase takeover
