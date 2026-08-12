# timer-engine

The engine gains two transition kinds — user adjustments and autostart-at-expiry — without surrendering its one law: remaining time is a pure function of recorded transitions and the current instant.

## MODIFIED Requirements

### Requirement: User-steerable timing policies
The engine SHALL support the four session policies from the approved mocks (gentle start 5+20, classic 25+5, flow open-ended, recovery-first) as data, SHALL additionally accept user-constructed policies (custom focus and break durations, long-break cadence), and SHALL NOT claim or encode any policy as optimal (research w2-breaks-adhd-falsification-001). The engine SHALL support a recorded adjustment transition (±60 seconds) while a block is running, an autostart transition recorded at the canonical expiry instant when the active block-end behaviour calls for it, and an auto-return transition recorded at the canonical break-end instant when auto-return is enabled. Policy changes SHALL never mutate history, and remaining time SHALL stay a pure function of recorded transitions and the current instant.

#### Scenario: Gentle start promotes without judgment
- **WHEN** a gentle-start 5-minute arrival period ends
- **THEN** the engine SHALL continue seamlessly into the main block and record the promotion as an ordinary event

#### Scenario: Flow policy has no forced end
- **WHILE** a flow session is `running`
- **THEN** the engine SHALL never auto-transition to break — including when autostart is enabled; only user intent or hold applies

#### Scenario: Custom policy is pure data
- **WHEN** a session runs under a user-constructed 40/8 policy
- **THEN** reconstruction from persisted transitions SHALL yield identical remaining time on relaunch

#### Scenario: Adjustment is a first-class transition
- **WHEN** an adjustment of +60 seconds is applied and the Mac then sleeps through the (shifted) expiry
- **THEN** wake SHALL backdate the expiry using the adjusted derivation, with no drift

#### Scenario: Autostart records at the canonical instant
- **WHEN** autostart applies and the app was not running at expiry
- **THEN** relaunch reconstruction SHALL place the break transition exactly at the expiry instant, not at wake or launch time

#### Scenario: Auto-return records at the canonical break-end instant
- **WHEN** auto-return is enabled and the chosen break length elapses — including while asleep
- **THEN** the engine SHALL record the return-to-focus transition at the canonical break-end instant, never at wake time, and with auto-return disabled breaks SHALL stay open-ended
