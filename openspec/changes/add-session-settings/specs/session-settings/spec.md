# session-settings

Rhythm, sound, and notification preferences behind a standard macOS Settings window. Every behaviour here bends to three standing invariants: no punitive mechanics, the engine is the only clock, and nothing in this capability is ever paywalled.

## ADDED Requirements

### Requirement: Settings scene
The app SHALL provide a standard macOS Settings window (⌘,) with Rhythm and Sound & Notifications panes, whose values persist through the injected defaults seam and survive relaunch; no setting SHALL write to the session store or alter its schema.

#### Scenario: Settings open by keyboard
- **WHEN** the user presses ⌘, from any surface
- **THEN** the Settings window SHALL open without disturbing a running session

#### Scenario: Preferences survive relaunch
- **WHEN** any setting is changed and the app is relaunched
- **THEN** the changed value SHALL be in effect at launch

#### Scenario: Settings do not touch the session store
- **WHEN** the store schema is compared before and after this change
- **THEN** entity and attribute sets SHALL be identical

### Requirement: Custom rhythm durations
The Rhythm pane SHALL let the user create, edit and remove focus-duration presets and break-duration presets, and configure a long-break cadence (every N blocks, longer length); durations SHALL become data-driven timing policies, and remaining time SHALL stay a pure function of recorded transitions and the current instant.

#### Scenario: A custom duration drives a session
- **WHEN** the user creates a 40-minute focus preset and begins a block with it
- **THEN** the engine SHALL derive remaining time from that policy's canonical timestamps with zero tick counting

#### Scenario: Long-break cadence suggests, never scores
- **WHEN** the configured cadence (every N blocks) is reached
- **THEN** the break surface SHALL present the longer break as the suggestion, with ordinary decline, and no streak, count-of-completions, or judgment SHALL render anywhere

#### Scenario: Removing a preset never corrupts history
- **WHEN** a preset used by past sessions is removed
- **THEN** past session records SHALL remain readable and unchanged

### Requirement: Autostart behaviour is the user's choice
The Rhythm pane SHALL offer exactly three block-end behaviours — break starts as the offered default; prompt first; fully manual — with **prompt-first as the shipped default**; the pane SHALL state that the flow policy is exempt, and WHILE the flow policy is active the engine SHALL never auto-transition regardless of this setting.

#### Scenario: Offered-default begins the break
- **WHEN** a focus block reaches expiry with behaviour "offered default"
- **THEN** the engine SHALL record the break transition at the canonical expiry instant and the break surface SHALL show declining or ending as one ordinary action

#### Scenario: Prompt-first asks gently
- **WHEN** a focus block reaches expiry with behaviour "prompt first"
- **THEN** a non-modal prompt SHALL offer the break, the session SHALL hold its place, and no urgency language SHALL appear

#### Scenario: Manual keeps today's behaviour
- **WHEN** a focus block reaches expiry with behaviour "manual"
- **THEN** the block-end presentation SHALL match current behaviour with no automatic transition

#### Scenario: Flow is exempt and says so
- **WHEN** the flow policy is active
- **THEN** the Rhythm pane SHALL visibly state the exemption and the engine SHALL record no automatic transition at any instant

#### Scenario: Autostart survives sleep honestly
- **WHEN** the Mac sleeps across an expiry with behaviour "offered default"
- **THEN** on wake the transition SHALL be backdated to the canonical expiry instant exactly as gentle-start promotion already is

#### Scenario: Auto-return offers focus at break end
- **WHEN** the auto-return toggle is on and the chosen break length elapses
- **THEN** the engine SHALL record the return to focus at the canonical break-end instant and the return overlay SHALL greet the user — an offer to re-enter, never a demand

#### Scenario: Auto-return defaults off
- **WHEN** the app runs with factory settings
- **THEN** breaks SHALL remain open-ended until the user ends them, exactly as today

### Requirement: Rewind and forward as recorded adjustments
WHILE a block is running, the user SHALL be able to nudge remaining time by ±1 minute via controls and the `+`/`-` keys; each nudge SHALL be a recorded engine adjustment transition, and remaining time SHALL remain a pure function of transitions and the current instant across sleep and relaunch.

#### Scenario: A nudge is an event, not a mutation
- **WHEN** the user presses `+` during a running block
- **THEN** the engine SHALL append an adjustment transition of +60 seconds and derived remaining time SHALL reflect it immediately

#### Scenario: Nudges survive relaunch
- **WHEN** the app relaunches after two `-` nudges
- **THEN** reconstructed remaining time SHALL include both adjustments exactly

#### Scenario: Nudges never rescue an expired block
- **IF** a block has already expired
- **THEN** adjustment controls SHALL be absent rather than disabled-looking

### Requirement: Sound cues, all optional
The Sound pane SHALL offer master volume and independent toggles for focus tick, break tick, focus-end chime, and break-end chime, plus a tick-loop toggle; every sound SHALL default OFF, be bundled (no network, no third-party audio packages), and be driven by engine state — a sound is presentation and SHALL never be state.

#### Scenario: Silence is the default
- **WHEN** the app runs with factory settings
- **THEN** no sound SHALL ever play

#### Scenario: Chime marks the canonical instant
- **WHEN** the focus-end chime is enabled and a block expires
- **THEN** the chime SHALL play once for that expiry, scheduled from the canonical expiry instant, with no repeating UI timer introduced

#### Scenario: Ticking stops with the session
- **WHEN** ticking is enabled and the session is held or closed
- **THEN** ticking SHALL stop within one tick period

#### Scenario: Sound failure is silent, never fatal
- **IF** an audio resource fails to load or the output device vanishes
- **THEN** the session SHALL continue unaffected and no error SHALL interrupt the user

### Requirement: Local notifications with honest text
The app SHALL offer optional local notifications for block-end and break-end with an optional bring-app-to-front action; shipped default texts SHALL pass the copy-tone lint, user-edited text SHALL be delivered verbatim as the user's own words, and notifications SHALL be scheduled from canonical instants only.

#### Scenario: Shipped defaults stay gentle
- **WHEN** the copy-tone lint runs over shipped notification defaults
- **THEN** zero strings SHALL match the banned-claims lexicon

#### Scenario: The user's words are theirs
- **WHEN** the user replaces a notification text with their own
- **THEN** it SHALL be stored and delivered verbatim with no lint gate at entry

#### Scenario: Denied permission degrades quietly
- **IF** notification permission is denied at the system level
- **THEN** the toggles SHALL reflect unavailability plainly and nothing SHALL nag for re-authorization

### Requirement: Settings are never paywalled
Every capability key introduced by this change SHALL resolve as available in Lite, and registry validation SHALL fail any configuration that withholds rhythm control, sound cues, or the settings scene from any edition's core support set.

#### Scenario: Hostile registry cannot gate settings
- **WHEN** a registry configuration attempts to mark session-settings keys as non-Lite
- **THEN** startup validation SHALL fail in debug and the keys SHALL resolve available in release
