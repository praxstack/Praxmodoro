# Atom 3.1 closed session-domain evidence

## Accepted result

Atom 3.1 is accepted by the milestone commit `feat: model focus session lifecycle`
on feat/native-app. It provides the closed,
Sendable session-domain vocabulary: lifecycle states, commands and events, snapshots,
projections, timing policies, privacy-safe effects, and invariant validation.

The final review found and then confirmed resolution of two acceptance blockers:

- a newly installed phase, break, or scheduled-check-in token must bind to the candidate revision;
- a recovery-contained re-entry timestamp must receive canonical field-specific validation.

## Verification

- Focused session-domain tests: 62 passed.
- Full core package: 85 tests in 4 suites passed.
- Strict OpenSpec trace: passed (57 criteria, 12 assumptions, 122 scenarios, 21 atoms).
- Project generation: passed.
- Unsigned warnings-as-errors macOS build: passed.

Atom 4.1 database safety remains explicitly deferred and unchanged.

Supported OpenSpec criteria: `E-001`, `E-003`, `E-004`, and `G-001`.
