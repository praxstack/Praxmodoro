# focus-loop-ui

The five core surfaces in the Living Companion language. Visual and behavioral truth traces to `design-mocks/living-companion/` (physics contract: `companion-physics.js`).

## ADDED Requirements

### Requirement: One-task initiation
The initiate surface SHALL ask for exactly one task, one tiny first action, a self-reported capacity (foggy/steady/restless/charged), and a timing policy, and SHALL show no other configuration on the start path (research w1-user-friction-004).

#### Scenario: Immediate start path
- **WHEN** the app opens with no running session
- **THEN** the initiate surface SHALL be presented with a single primary begin control reachable by one click or ⌘↩

#### Scenario: Advanced options stay out of the way
- **WHEN** the initiate surface renders
- **THEN** no analytics, integrations, or settings controls SHALL appear inside the start path

### Requirement: Focus surface keeps task and time legible
WHILE a session is `running`, the focus surface SHALL keep the task, next action, and remaining time visible, with the companion field as ambient presence — never as a score, gauge of performance, or character with a face.

#### Scenario: Nothing scores the user
- **WHEN** the focus surface renders in any state
- **THEN** no element SHALL display streaks, grades, productivity percentages, or comparative judgments

#### Scenario: Thought parking without context loss
- **WHEN** the user captures a thought from the focus surface
- **THEN** the thought SHALL be appended to the local parked list and focus SHALL remain the active surface

### Requirement: Companion field physics
The companion field SHALL implement the approved physics contract: asymmetric breathing with exhale longer than inhale, spring-damped state transitions (gathering, breathing, held, ripple, expanded, settled), non-repeating drift, and a soft acknowledgement pulse on user choices — implemented in pure SwiftUI/Metal with no third-party effect packages (research w2-effects-dependency-audit-004).

#### Scenario: Pause exhales to stillness
- **WHEN** the user holds the timer
- **THEN** the field SHALL glide to near-stillness with spring momentum rather than freezing on the next frame

#### Scenario: Choice acknowledgement
- **WHEN** the user selects a check-in answer
- **THEN** the field SHALL produce one damped pulse with at most one visible overshoot

### Requirement: Check-in with no failure state
The check-in surface SHALL offer exactly four answers (still fits / make the step smaller / drifted / need a break), SHALL hold the timer while open, and SHALL respond to every answer with next-step language that never grades, moralizes, or records a streak.

#### Scenario: Drift is information
- **WHEN** the user answers "I drifted somewhere else"
- **THEN** the response SHALL name the detour as information and offer return, re-plan, or close — with identical visual weight

#### Scenario: Check-in never interrupts destructively
- **WHEN** a check-in becomes due WHILE the user is mid-keystroke in thought parking
- **THEN** the check-in SHALL wait for the field to lose focus before presenting

### Requirement: Break with a held place and re-entry card
The break surface SHALL present suggestions derived only from the user's own reports, SHALL never claim an optimal cadence, and SHALL show a re-entry card carrying the exact next action for the return.

#### Scenario: Ending early is ordinary
- **WHEN** the user ends a break before its suggested duration
- **THEN** the session SHALL resume with no notice, penalty, or altered future suggestion weight

#### Scenario: Suggestion provenance is disclosed
- **WHEN** a break suggestion renders
- **THEN** an expandable "why this suggestion" disclosure SHALL name the user-reported inputs behind it and state that the pattern is editable and can be disabled

### Requirement: Review is a record, not a verdict
The review surface SHALL show a chronological timeline of session events with descriptive, uncertainty-aware insight copy, and SHALL NOT diagnose, grade, or make medical or treatment claims (research w2-breaks-adhd-falsification-004).

#### Scenario: Single-day observations stay tentative
- **WHEN** an insight derives from one day of data
- **THEN** its copy SHALL state the observation's limits (e.g. "one afternoon is not a pattern")

### Requirement: Complete accessibility alternates
Every surface SHALL provide full alternates: Reduce Motion or "Motion: still" SHALL stop the physics engine entirely and present a calm static field; Reduce Transparency SHALL replace translucent veils with solid semantic backgrounds; Increase Contrast SHALL meet contrast ratios on every text and control; every control SHALL be keyboard-reachable and VoiceOver-labeled.

#### Scenario: Reduce Motion standdown is total
- **WHEN** system Reduce Motion is on or the user selects "Motion: still"
- **THEN** the physics engine SHALL not run, the field SHALL render its static alternate, and no continuous animation SHALL play anywhere

#### Scenario: Full keyboard loop
- **WHEN** a user operates only the keyboard
- **THEN** begin, hold/resume, check-in answers, break choices, thought parking, and surface navigation SHALL all be reachable and visibly focused

#### Scenario: VoiceOver on the field
- **WHEN** VoiceOver focuses the companion field region
- **THEN** it SHALL read a concise state description (e.g. "Companion: breathing, 17 minutes remaining") and the decorative layers SHALL be hidden from the accessibility tree

### Requirement: Non-medical language everywhere
All UI copy SHALL use non-medical positioning ("ADHD-aware", "designed with executive-function challenges in mind") and SHALL NOT include diagnostic, therapeutic, or outcome claims.

#### Scenario: Copy audit gate
- **WHEN** the copy audit test runs over all user-facing strings
- **THEN** zero strings SHALL match the banned-claims lexicon (treat, cure, diagnose, clinically proven, optimal schedule, and equivalents)

### Requirement: Edition gating seam without gated behavior
Every surface SHALL consult the capability registry for feature availability, and in this change the Lite grant SHALL include all surfaces and behaviors.

#### Scenario: Lite includes the whole loop
- **WHEN** the app runs with the Lite edition flag
- **THEN** all five surfaces and all behaviors in this spec SHALL be available with no upsell present on any of them
