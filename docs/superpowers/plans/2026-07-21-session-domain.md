# Session Domain Execution Plan

> **Required mode:** OpenSpec-driven, test-first, subagent-reviewed, one accepted atom per commit.
> This plan is executable only after `semanticContractGate.status == done`. The normative value,
> transition, timing, event, failure, and ownership contract is
> `docs/specification/session-domain-contract.md`; this file does not redefine it.

**Goal:** Implement the deterministic local session foundation behind Praxodoro's complete ADHD-aware
focus loop without allowing UI, persistence, clocks, entitlements, or platform effects to become
alternate sources of session truth.

**Architecture:** Atom 3.1 introduces immutable closed values and candidate validation only. Atom 3.3
then adds the pure paired wall/monotonic projector/time kernel, boundary arbitration, and recovery
decisions without a reducer stub. Atom 3.2 integrates that accepted kernel into the exhaustive pure
reducer and coach rules. Atom 4.1 adds the actor and atomic in-memory repository. Each atom
starts with a focused failing test, runs the full package regression, receives independent code/spec
review, passes the receiving-implementer gate, and commits before the next atom begins.

## Frozen ownership boundary

| Atom | Creates behavior | Must not create |
|---|---|---|
| 3.1 | closed values, constructors, exact defaults/presets, projections/errors as values, invariant validator | reducer, callable projector, clocks, repository, platform effects |
| 3.3 | callable projector and pure time kernel, paired elapsed, drift/relaunch decisions, token values, due arbitration | reducer matrix/event envelopes, actor, persistence |
| 3.2 | pure non-throwing reducer integrating 3.3, exhaustive matrix, coach suggestions, ordered events/effects | new wall/monotonic algorithms, actor, persistence |
| 4.1 | actor serialization, revision gate, atomic in-memory commit, publication/effect order | SwiftData, notification implementation, views |

No later-atom stub is acceptable. If an Atom 3.1 test requires Atom 3.2/3.3 behavior, the test is
mis-scoped and must move instead of forcing a placeholder implementation.

---

## Atom 3.1 — Closed Session Model

**Create:**

- `Packages/PraxodoroCore/Sources/PraxodoroCore/Session/SessionState.swift`
- `Packages/PraxodoroCore/Sources/PraxodoroCore/Session/SessionIntent.swift`
- `Packages/PraxodoroCore/Sources/PraxodoroCore/Session/SessionEvent.swift`
- `Packages/PraxodoroCore/Sources/PraxodoroCore/Session/SessionProjection.swift`
- `Packages/PraxodoroCore/Sources/PraxodoroCore/Session/TimingPolicy.swift`
- `Packages/PraxodoroCore/Tests/PraxodoroCoreTests/SessionModelTests.swift`

### Step 1: Freeze the pre-change candidate

Run and retain output:

```bash
npm run spec:validate
swift test --package-path Packages/PraxodoroCore
bash scripts/verify-project-generation.sh
git status --short
```

Kill the atom if the semantic gate is not accepted, the index/worktree contains an unrelated source
change, or the existing 20 package tests do not pass.

### Step 2: Write one real compile-time RED

Create `SessionModelTests.swift` with an initial suite that names production symbols from each owned
group:

- `SessionState` and all ten `SessionStateKind` cases;
- lawful `SessionTimestamp` equality/hash semantics and non-Equatable raw clock observations;
- `SessionIntent`, `SessionCommand`, and every `SessionIntentKind` mapping;
- `SessionEventPayload`, `SessionEffect`, result/rejection/failure vocabularies;
- `SessionConfiguration.defaults` and all four `TimingPolicyID` values;
- `SessionSnapshotValidator.validate(previous:command:candidate:emittedEvents:context:)`;
- `SessionProjection` and `ProjectionError` value construction only.

Run:

```bash
swift test --package-path Packages/PraxodoroCore --filter SessionModelTests
```

Accepted RED: exit nonzero and compiler diagnostics naming missing session-domain symbols. Reject a
zero-selected-test result, a test-discovery failure, or a failure caused only by malformed test code.
Record the command, exit code, and decisive diagnostic in the Atom 3.1 evidence file.

### Step 3: Implement validated scalar and configuration values

Implement the public constrained constructors before canonical state fixtures:

- normalized task/action/thought/detour/reflection text limits;
- check-in interval, captured remainder, break duration, and phase duration ranges;
- capacity and exact session configuration defaults;
- non-empty plan/configuration change-set factories;
- explicit `Equatable`, `Sendable`, and required `Hashable` conformances.

Add constructor-negative tests for every unconstructable invalid value and boundary fixtures for all
minimum/maximum/out-of-range values named in Section 11.1 of the contract.

### Step 4: Implement exact timing policies and Lite mapping

Implement Gentle Start, Classic, Flow, and Recovery First as the exact frozen data values. Tests must
compare complete values, not selected fields, and must prove:

- every policy maps to its exact `RequiredLiteFeature`;
- no policy requires an optional paid capability;
- phase identifiers, durations, open-ended shapes, and no-auto-chain rules match the contract;
- `SessionConfiguration.defaults` is a complete equality fixture.

### Step 5: Implement closed state and timing vocabulary

Implement internal canonical construction for:

- idle, prepared, focusing, paused, checking-in, breaking, re-entering, reviewing, completed, and
  recovery-needed states;
- timed/open-ended focus, pause, suspension, and break shapes;
- scheduled check-in boundaries plus phase/scheduled/break token discriminants;
- immutable snapshot counters, observations, plan, thoughts, review, and recovery values.

Tests construct one valid internal fixture for every lifecycle/timing shape and compare every explicit
kind mapping with no `default` switch branch.

### Step 6: Implement commands, events, effects, and failure values

Implement the complete closed command and factual-event vocabulary, including recursive privacy-safe
payloads and field-specific timestamp identifiers. Tests must prove:

- one explicit kind mapping per state, intent, event payload, effect, and check-in response case;
- event envelope version/sequence construction;
- no event payload or nested value can store raw task/action/thought/detour/reflection/check-in answer;
- all optional event payload and nested clock-adjustment dates have exact timestamp-field coverage;
- notification effects are token-derived and always use private generic content;
- every rejection, no-change, reduction failure, engine failure, recovery reason, repository failure,
  effect status, and platform status is constructible and equality-safe.

Do not implement `SessionReducer.reduce` or `SessionProjector.project` in this atom.

### Step 7: Implement candidate validation

Implement a validator that returns the complete set of applicable violations and never clamps or
repairs. Partition tests by invariant row:

1. schema, the exact revision-0 idle baseline, the complete idle/completed-to-prepared reset,
   identity, revision, event sequence, and boundary occurrence;
2. plan/start/last-wall requirements;
3. timestamp quantum for every `SessionTimestampField`, including fractional, NaN, and infinity;
4. accumulator/counter regression;
5. configuration and change-set shape;
6. focus/pause/suspension/break timing relationships;
7. disjoint check-in shapes, including phase-boundary continuation with no fabricated suspended
   remainder and exact scheduled-cadence preservation/reset;
8. installed and historical token discriminants/revisions/occurrences;
9. scheduled boundary atomicity and exact deadline/remainder relation;
10. thought limits, uniqueness, normalization, and deterministic order;
11. review/completion privacy, finite-rollback summary timestamps, and total consistency;
12. recovery frozen-timing shape and exact safe choices;
13. relational previous/candidate/event/context commit invariants, including allowed non-live wall
    rollback and live adjustment precedence.

Malformed fixtures use internal canonical initializers through `@testable import`. Public invalid
values use constructor-negative tests; do not add unsafe public fixture factories.

### Step 8: Focused GREEN and full regression

Run:

```bash
swift test --package-path Packages/PraxodoroCore --filter SessionModelTests
swift test --package-path Packages/PraxodoroCore
npm run spec:validate
bash scripts/verify-project-generation.sh
xcodebuild -project Praxodoro.xcodeproj -scheme Praxodoro \
  -destination 'platform=macOS' -derivedDataPath .build/Atom31DerivedData \
  build CODE_SIGNING_ALLOWED=NO
git diff --check
```

Required GREEN evidence includes exact focused/full test counts, zero skipped mandatory tests, strict
OpenSpec trace totals, deterministic generation, and a successful native build.

### Step 9: Independent review and receiving gate

Dispatch separate technical reviewers for:

- code quality, Swift 6 concurrency, API visibility, and exhaustive switches;
- OpenSpec/session-contract fidelity and exact owned-scope boundaries;

Resolve every Critical/Major/Important finding. Convene the quick shipping council only after both
technical reviews return READY. Then, before the final receiving review:

1. Check OpenSpec task 3.1 and only 3.1.
2. Set PRD Atom 3.1 to done, next atom 3.3, and attach the conditional evidence path.
3. Finalize the evidence file and append RED, GREEN, technical-review, council, anomaly, and
   `RECEIVING_CANDIDATE` entries to `progress.txt`; do not claim an ACCEPT verdict that has not yet
   happened.
4. Stage the complete exact Atom 3.1 payload except the receiving review's own receipt, then run all
   cached/index checks plus focused/full tests.
5. Have the receiving reviewer inspect that actual staged payload and confirm the exact allowlist,
   content digest, test receipts, lifecycle metadata, and absence of Atom 3.2/3.3 implementation.
   The reviewer creates and stages only its own ACCEPT receipt, which is excluded from the payload
   digest to avoid self-reference.
6. Rerun the final read-only cached/index validation and focused/full tests. Any payload mutation,
   including task/PRD/progress/evidence changes, invalidates ACCEPT and requires another final-index
   receiving pass.

### Step 10: Atom 3.1 milestone commit

Only after the final staged receiving verdict is ACCEPT:

1. Make no further file or index mutation.
2. Commit the already reviewed index exactly as `feat: model focus session lifecycle`.
3. Verify the commit contains the accepted path/content digests, post-commit generation is no-diff,
   strict validation remains green, and the scoped worktree is clean.

---

## Later atom entry criteria

### Atom 3.3

May start immediately after Atom 3.1. It creates the pure tested kernel that Atom 3.2 consumes and no
reducer/event-envelope stub. Its RED and GREEN must cover the paired `100.9 + 0.2 == 1 second` fixture;
typed start/resume/break entry and scheduled-replacement materializations with exact anchor-plus-deadline,
phase/scheduled/break token order, final occurrence, non-finite/date/occurrence failures, and
manual/5/120-minute captured-remainder values for suspended schedule changes;
exact ±1/±2 admission-versus-live-materialization drift outputs; exact non-boundary focus
timing/cadence and break accumulation; future-cadence preservation versus equal-time and
overdue-later-scheduled reset decisions; scheduled-earlier/phase-later/both-overdue
winner-time accumulation plus positive phase suspension without irrelevant observation-total
overflow, and exact recovery when the winner total itself overflows; any positive future relaunch
anchor through the pure
`reconcileRelaunch` API; current-wall versus missing/stale/raw-invalid precedence; installed-token/due
decisions; sleep; DST; Flow; and one-winner boundary selection. Duplicate/stale preclassification and
all candidate/event assertions remain Atom 3.2 work. Atom 3.2 must additionally prove ordinary
due-boundary supersession versus terminal Stop/Replace-and-Review winner-time review materialization,
including expected-paired review `endedAt` versus observed event-envelope timestamps; every other
canonical transition timestamp source, including observed-wall `pausedAt` when a resume-suspended
check-in resolves back to paused; and revised-action replacement of the plan/final-summary source of
truth.

### Atom 3.2

May start only after the accepted Atom 3.3 commit. Its RED must name missing reducer/coach behavior,
and its matrix report must cover every listed row plus every default rejection while delegating all
clock arithmetic to the time kernel. It owns non-finite-wall classification for otherwise
transitioning non-live families, duplicate/stale callback classification, and maps every 3.3
live/relaunch/admission decision into candidates/events/effects.

### Atom 4.1

May start only after Atoms 2.2, 3.2, and 3.3. It must prove actor serialization, expected-revision
precedence, snapshot+event atomicity, conflict reload classification, publish-after-commit,
effect-after-publication, and same-named zero-write mapping for every reduction failure.

## Cross-atom kill criteria

- Any callable reducer/projector/engine stub in an earlier atom.
- Any per-second persistence tick or view-owned timer.
- Any event containing raw user text or raw coaching answers.
- Any default switch hiding an unhandled closed-enum case.
- Any repair/clamp inside candidate validation.
- Any product-capability query inside the pure reducer.
- Any completion claim based only on type existence or a narrow focused test.
- Any milestone commit before code review, spec review, council, and receiving-index acceptance.
- Any semantic acceptance/reacceptance that fabricates changes to unchanged reviewed files: the
  commit must contain every required transition receipt/metadata/contract path and only paths from
  the allowed manifest; the receiving receipt binds the actual changed-path set plus Git file modes
  and bytes, while the subject digest binds unchanged reviewed subject paths from the index.
- Any working-tree or Git-index byte change to the accepted session-domain contract while
  `semanticContractGate.status` remains `done`; strict validation must fail, including when an
  unreviewed edit exists only in the index, until the gate is set to `in_review` and a new exact
  staged review/council/receiving transition becomes the latest reserved semantic-gate commit.
