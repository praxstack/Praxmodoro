# Architecture stabilization and milestone close-out plan

Date: 2026-08-23
Branch: `prax/architecture-review-2026-08-23`
Frozen baseline: `a78e0e04cbf5cfe75582e50bfd0ec6b2afb0a4e7`
Active changes: `add-companion-surfaces`, `add-session-settings`, `stabilize-runtime-contracts`
Status: implementation and reviewed repair atoms committed; current signed UI execution, fresh validator, and archives pending

## Objective and success definition

Close the verified M2 and `add-session-settings` compliance defects, land the owner-approved runtime-contract prerequisite (#51–#53), and archive only changes that pass current evidence rather than historical assertions.

Done means:

1. all three OpenSpec change trees are complete, internally consistent, and strict-valid;
2. Codex, Grok, the documented MOA-equivalent council, independent validators, and the requested planning reviews have no unresolved critical/major finding;
3. every behavior repair starts with an observed failing test;
4. the complete implementation diff passes iterative code review before any implementation commit;
5. Core, Store, focused, signed full, smoke, generation/lint, and strict spec gates pass from a fresh shell;
6. `prd.json` and `progress.txt` record actual red→green evidence and atom SHAs;
7. M2, `add-session-settings`, and the runtime-contract change archive in dependency order; and
8. the final scoped commit contains only reviewed archive/status evidence.

This run does not claim backlog or delivery completion. It claims only that the three change specifications are technically ready for implementation once the owner gate clears.

## Source-of-truth reconciliation

| Source | Verified status | Effect on this plan |
|---|---|---|
| `SPEC.md` | M2 still requires fresh validation/archive | M2 remediation and a COMPLETE validator verdict gate every later archive claim |
| `prd.json` / `progress.txt` | reconciled 2026-08-23 to the `architecture-stabilization` batch with pending current atoms and preserved historical evidence | treat the current owner-decision-blocked state as authoritative; never copy or infer receipts |
| `add-companion-surfaces` | prior boxes were checked, fresh validator found four defects plus keyboard gap | reopen close-out and add tasks 10–11; no new capability spec required |
| `add-session-settings` | tasks 9.2/9.3 open; fresh validator found product, UI, race, and evidence gaps | amend the active capability with owner issue #18 and add remediation tasks |
| issues #51–#53 | `ready-for-agent`; prerequisite to later persistence/timeline work | after M2, land runtime C1/C2 before settings B3 so C2 supplies `breakEndInstant` and `autoReturnAfter`; C3 follows in the same narrow runtime change |
| issue #18 | later explicit owner decision | supersedes the settings change's earlier factory-silence text: start + both chimes on; ticks off; five samples |
| issue #7 | M2 close-out umbrella | existing issue; do not duplicate |
| enterprise-grade plan | owner-approved Approach B trust pass | this plan is the evidence-first prerequisite rung, not the later schema/controller program |

## Verified architecture

```text
SwiftUI scenes/surfaces
  |  intents and immutable CompanionDisplay
  v
AppModel  ---------------- presentation seams ----------------> sound / notifications
  |  one codec-backed transition append
  |  store I/O + atomic application of pure replay result
  v
PraxmodoroStore (SwiftData append-only values)
  |
  +---- StoredEvent[] ----> SessionReplay (app integration boundary)
                               |
                               v
                        PraxmodoroCore.Session
                               |
                         canonical timestamps
                               |
             expiryInstant / breakEndInstant / reconciled
```

Boundaries that already hold and will be reused:

- Core owns deterministic state and timestamp arithmetic; no timer rewrite is needed.
- Store and Core remain independent; the app target is the only layer importing both.
- `SessionSnapshot`/`CompanionDisplay` already prevent companion surfaces from owning time.
- `CapabilityRegistry`, `SurfacePalette`, `DesignTokens`, injected defaults, sound, notification, and ephemeral-store seams already exist.
- `focused.sh`, `verify-project.sh`, `smoke.sh`, strict OpenSpec validation, and signed UI tests already provide named gates.

## Required architecture changes

### Phase 0 — truthful status before production

During specification review and before the first production or test edit, reconcile status early enough that final reviewers inspect the truthful work batch. This phase does not change an acceptance threshold and may precede the final reviewer reruns:

1. update `SPEC.md` with a dated status note that M2 and `add-session-settings` were reopened by the 2026-08-23 validators; do not change any acceptance threshold;
2. change `prd.json`'s stale single-change/M3 header to an `architecture-stabilization` work batch with an `activeChanges` array naming the three approved OpenSpec changes, and append pending atoms for one-product provenance, M2 capability/contrast, M2 snapshot/overlay, M2 keyboard close-out, settings presets/tokens, settings denial, settings sound/compatibility/auto-return, runtime replay, runtime break end, runtime surface intent, and final close-out; retain every historical atom/evidence entry unchanged;
3. append a `progress.txt` status-reconciliation receipt that distinguishes historical green evidence from the newly pending repairs; and
4. correct README's “one open item” claim and remove the false `BLUEPRINT.md` promise, replacing both with the three active change paths and current runnable commands.

This is a documentation/state reconciliation, not a completion claim. It is itself included in the later whole-diff review and remains uncommitted until that review is clean.

### Lane A — M2 compliance repairs

Specification: existing `add-companion-surfaces` EARS requirements and amended design/tasks.
Detailed plan: `docs/plans/2026-08-23-m2-validation-remediation.md`.

1. Apply owner-authorized issue #34: one product, no Edition API or tier copy; keep feature-key provenance and hostile-fixture validation.
2. Consult existing capability keys at each companion scene/overlay construction site.
3. Wire Increase Contrast through existing palette tokens on capsule and return overlay.
4. Render all FocusSurface values from one root `TimelineView` context snapshot.
5. Make acknowledgement the only in-process way to clear the return overlay.
6. Complete signed keyboard evidence for hold/resume, thought parking, break choice, and visible focus.

### Lane B — `add-session-settings` contract and validation repairs

Specification: amended `add-session-settings` proposal/spec/design/tasks.
Detailed plan: `docs/plans/2026-08-23-m3-validation-remediation.md`.

1. Make focus and break presets editable/removable and every configured pair reachable.
2. Prove preset deletion does not change persisted historical derivation.
3. Wire settings colors/contrast to the existing palette/token layer.
4. Cancel/resynchronize notification work when async availability returns denied.
5. Implement owner issue #18: fifth block-start cue, factory-on start/end chimes, ticks off, five sample buttons.
6. Preserve pre-block-start saved preferences through keyed decoding, defaulting only the new cue off for existing users.
7. Make all five sample buttons keyboard reachable through the exact `AppModel.previewSound(_:)` seam.
8. Materialize live derived auto-return on every root context-date edge, using Core's process-live boundary so a complete cycle across sleep is observed once and an absent relaunch interval is never caught up.
9. Make future/completed audio-player retention explicit through `shouldRetainChime(scheduledAt:now:isPlaying:)`.
10. Rebuild settings-change evidence without inventing historical receipts and obtain a fresh COMPLETE verdict.

### Lane C — runtime contracts (#51–#53)

Specification: `openspec/changes/stabilize-runtime-contracts/`.
Detailed plan: `docs/plans/2026-08-23-runtime-contract-foundation.md`.

1. Add a strict payload codec over Core `SessionState`, one transition-append helper, pure deterministic replay, and atomic restore application.
2. Add `breakEndInstant(cadence:)`, migrate `reconciled(autoReturn:)` to a Boolean gate, and add the process-live `autoReturnAfter` fence so one Core instant owns duration and absence remains absence.
3. Make `AppModel.surface` `private(set)` and route review through `beginNextSession()`.

## Ordering and parallelization

| Step | Modules | Depends on |
|---|---|---|
| P0 status reconciliation | SPEC/prd/progress/README only | strict-valid amended specs; before final reviewer reruns and production |
| A0 one-product contract | registry/provenance/docs/tests | P0 |
| A1 capability/contrast | app scenes + companion surfaces/tests | A0 |
| A2 snapshot/overlay | AppModel + focus/overlay tests | A1 only for shared review, not behavior |
| A3 keyboard evidence | signed UI target | A1–A2 green |
| B1 presets/tokens | settings surfaces + preferences/tests | final spec review |
| B2 notifications | AppModel + notification tests | final spec review |
| B3 sounds/auto-return/audio | AppModel + sound/preferences/resources/settings/UI tests | B1 token shape; C2 process-live boundary |
| C1 replay payloads | AppModel + lifecycle tests | A3/B2 green; final spec review |
| C2 break instant/live fence | Core + AppModel + timing tests | C1 green |
| C3 surface intent | AppModel + review surface/tests | A2 overlay/model behavior stable |

The code lanes are logically independent but share `AppModel.swift`, surface tests, and full signed build products. Implement sequentially in this branch to preserve red→green evidence and avoid merge conflicts:

```text
P0 → A0 → A1 → A2 → A3 → B1 → B2 → C1 → C2 → C3 → B3 → whole-diff review → commits
```

No parallel worktree implementation. Read-only reviewers may run in parallel.

## Design-complete interaction decisions

| Feature | What the user sees | Empty/unavailable behavior |
|---|---|---|
| return overlay + check-in | re-entry card stays above focus; requested check-in holds once and waits | Continue clears overlay and routes to the waiting check-in; no silent dismissal or duplicate hold |
| companion contrast | same layout/copy with higher-contrast primary token | system setting off uses standard token |
| editable presets | inline minute row with Remove; Add stays in place | built-in-policy message remains when list empty |
| sound rows | five rows, each label + toggle + keyboard-reachable sample; master volume above | missing audio remains silent; controls stay usable |
| denied notifications | plain System Settings explanation; notification group disabled | callback cancels pending request immediately |

No new loading screen, card system, modal, navigation level, animation, or responsive form factor is introduced. Native macOS Form, Window, focus traversal, minimum control sizes, VoiceOver labels, Reduce Motion, Reduce Transparency, and Increase Contrast remain binding.

## Error and recovery contract

| Boundary | Failure | Required outcome | User visibility in this run |
|---|---|---|---|
| replay encode | synthetic idle requested | typed error; no append | programmatic only |
| replay decode | unknown transition/malformed adjustment | typed error; model unchanged | launch still suppresses until #35/#36; no fabricated state claim |
| store read | SwiftData error before a complete input set exists | propagate the existing error; this change makes no store-boundary partial-fetch or atomicity guarantee | #35/#36 deferred |
| closed replay | valid closed session | pure result returned; AppModel leaves pre-call state unchanged | fresh launch stays initiate |
| live/absent return | phase equality hides a full cycle, or relaunch starts after break end | observe every root date edge; Core returns only after a break end later than `liveObservationStartedAt` | witnessed sleep returns; absent break stays open |
| notification availability | callback returns denied after scheduling | unavailable state plus immediate cancel/resync | plain disabled controls/message |
| sound resource/device | unavailable | session unaffected; debug-only log | intentionally silent |
| smoke/full gate | host build stalls or exits nonzero | no completion/commit; diagnose and rerun fresh | build evidence only |

## Test and evidence matrix

| Contract | Red proof | Green proof |
|---|---|---|
| M2 capability/contrast | exact scene-guard and actual-surface raster tests fail | each construction is enclosed by its direct registry guard; capsule/overlay pixels gain contrast |
| M2 one instant/overlay | mixed Date/context and implicit clear tests fail | root-context snapshot injection; check-in waits/holds behind acknowledgement |
| M2 keyboard | signed XCUITest lacks required key paths/focus | named controls report `hasKeyboardFocus` before key activation on unlocked host |
| settings presets/history | edit/pair/history tests fail | every pair reachable; old stored session unchanged |
| settings denial race | deferred callback leaves request pending | callback cancels and blocks reschedule |
| settings sound/compatibility | four-cue/silent-default expectations fail; legacy blob falls back | five assets/rows/samples, exact transition edges, old values preserved; five UI buttons take focus |
| live auto-return | phase-only callback misses a full focus→break→focus cycle or later catches up an absent one | every root date edge is observed; Core process-live fence materializes witnessed sleep once while restored absence stays open forever |
| audio retention | future stopped player or past completed player is handled alike | pure predicate retains `isPlaying || scheduledAt > now` only |
| generated project | new Swift source is absent from an existing project | focused check regenerates first; generated project remains ignored |
| replay boundary | missing codec/helper and sentinel atomic cases fail | one append site; strict pure replay; no partial model state |
| break authority | missing method/Boolean/fence/agreement tests fail | Core/AppModel boundary, sound, and notification use one instant and one process-live boundary; the live-auto-return row owns observer proof |
| surface authority | public setter/direct view write fail | compiler-private setter plus model intent |

Each atom records: test command, expected red reason, minimal production diff, green command/result, files, and post-review commit SHA.

## Commit and archive protocol

1. Keep production/test work uncommitted while implementing because the user forbids commits before all code-review findings close.
2. Run the named code-review workflow plus independent adversarial/fresh-context implementation validation over the complete uncommitted diff.
3. Fix every finding and re-run reviewers until clean; never weaken a test or criterion.
4. Run all fresh gates over the reviewed complete diff.
5. Use inspected hunk staging for shared files, starting only when the index is empty. Capture the SHA-256 of `git diff --binary HEAD` for the reviewed candidate, stage exactly one atom, inspect `git diff --cached`, and write the index with `git write-tree`. Create a `mktemp -d` detached worktree at current `HEAD`, apply that exact tree to its own index/worktree with `git read-tree --reset -u <tree>`, and run the atom's focused checks there; remove only that validated temporary worktree afterward. Require those isolated checks to pass, require the full reviewed-diff hash in the main worktree to remain unchanged before commit, and record a hash of the unstaged residual patch so it can be proven byte-identical after commit. Tests in the main worktree do not count as per-commit isolation.
6. Use conventional commits; one independently testable remediation/runtime atom per commit.
7. After atom commits, update active task checkboxes plus `prd.json`/`progress.txt` with observed evidence and SHAs; run each change's fresh-context validator over the committed implementation and uncommitted receipts. If it finds production or test work, stop archive, add/retain a failing regression, make the minimal uncommitted fix, rerun code review and adversarial review, rerun affected and full fresh gates, prove the staged repair in the isolated-tree procedure above, commit it as its own implementation atom, update evidence, and rerun the validator. Documentation-only corrections still require strict validation and an evidence update. Never hide implementation in the archive/status commit, and require COMPLETE before archive.
8. Archive in dependency order: M2 → runtime contracts → `add-session-settings`. Each archive must sync its deltas into canonical `openspec/specs/`. Because OpenSpec 1.6 gives newly created canonical capabilities a generated `TBD` Purpose, replace the new `companion-surfaces` Purpose from its delta immediately after the M2 archive and the new `session-settings` Purpose from its delta immediately after the settings archive; normalize archive-updated canonical Markdown to one trailing newline. Only then run `npm run docs:build`, strict validation, diff integrity, and the change-specific stale-term/source scans before starting the next archive.
9. Update `SPEC.md` and README only with actual archived outcomes. After the M2 archive, require the broad case-insensitive whole-word product-vocabulary ban from M2 task 10.0 over production `app/Sources/**/*.swift`, Core `Sources/**/*.swift`, and `scripts/generate.sh`. Separately scan canonical specs, `openspec/config.yaml`, AGENTS, SPEC, README, source/test spec-reference comments, and only their generated counterparts (`docs/site/AGENTS.html`, `README.html`, `SPEC.html`, and `openspec-specs-*.html`) for the deprecated phrases `Edition capability registry`, `Edition gating seam`, `Edition-neutral storage`, `UI-free and edition-free`, `edition concerns`, `identical across editions`, `Lite grants`, `Lite edition`, `Pro edition`, `Enterprise edition`, `Lite, Pro, and Enterprise`, `Deterministic versioning and provenance`, `Companion surfaces are never paywalled`, `Settings are part of the one product`, `testSchemaParityAcrossEditions`, and `TBD - created by archiving`; exclude historical plans, active delta pages quoting old `FROM` names, and archived change records. Then run the final full gate and independent validator over the archived tree.
10. Create one final archive/status commit. Close/reconcile GitHub tickets only after that commit exists.

## Implementation tickets

Ticket conversion runs only after all specification/plan reviews are green. Reuse #7, #18, and #51–#53. Create no duplicate umbrella. New tickets may cover only validator-derived work not already represented:

- M2 runtime/accessibility validation remediation;
- settings preset/token/notification validation remediation;
- settings evidence and archive gate if it cannot live in the remediation ticket.

Every ticket must copy acceptance criteria from the approved artifacts, include exact verification commands, dependency links, and `ready-for-agent` only after the spec freeze.

## NOT in scope

- #35/#36 startup persistence-error UI: needed before claiming user-visible recovery, but not required for typed replay correctness.
- #37 schema migration, #21 event editing, #22 reconstructed review: downstream of runtime contracts.
- broad `AppModel` decomposition or actions protocols: no current acceptance test needs them.
- companion-field fidelity, token-migration batches, Appearance & Presence, global hotkeys, haptics, imported sounds, network/sync/analytics/AI.
- unknown stored event-kind/schema migration and O(n) store order indexing: verified architecture debts, but outside these approved changes and not required by their EARS scenarios.
- parked-thought carryover between sessions and capacity restoration: verified state-continuity debts tracked by #41 or a follow-up; neither is required by these three active changes.

## Stop and rollback rules

- Rollback pointer: `a78e0e04cbf5cfe75582e50bfd0ec6b2afb0a4e7`.
- Stop before production edits while any spec/plan reviewer has an unresolved critical/major finding.
- Stop before archiving `add-session-settings` unless the owner explicitly rules on the immutable grouped-commit deviation; never convert absent historical red receipts into inferred evidence.
- Stop before commits while any code-review finding remains open or any required check is nonzero.
- Stop after two no-gain repair attempts on the same failure; report the stall instead of weakening the gate.
- No schema migration occurs in these lanes; reverting scoped commits requires no user-data transform.

## Review ledger

| Reviewer | Runs | Findings | Resolution | Status |
|---|---:|---:|---|---|
| spec-creator self-review | 2 | 4 | fixed command precision, concrete replay types, atomicity, archive ordering; final strict recheck passed | CLEAR |
| Codex | 5 | 19 across four rejection passes | fixed routing, replay, tests, staging, auto-return semantics, ownership boundaries, evidence EARS, and generated-page drift; targeted recheck returned `CLEAR` | CLEAR |
| Grok | 2 | 4 | fixed snapshot, contrast, hostile-registry, and configuration contradictions; targeted recheck returned `CLEAR` | CLEAR |
| MOA-equivalent council | 2 | 12 overlapping runtime/M2 findings | independent bounded reviews plus root synthesis incorporated every finding | CLEAR |
| M2 validator | 1 | 4 blockers + 1 evidence gap | reopened M2; tasks/design/plan amended | REJECT until implementation |
| settings validator | 1 | 6 blockers + 2 minors/evidence | settings spec/design/tasks/plan amended | REJECT until implementation |
| independent subagent | 3 | 7 | fixed cross-change ownership and test-plan inconsistencies; final targeted recheck returned `CLEAR` | CLEAR |
| CEO review | 1 | 1 P1 governance decision | owner pre-approved the specifications and documented historical deviation in the active completion goal | CLEAR |
| engineering review | 1 | 1 P1 evidence decision | owner accepted the deviation; immutable history and missing-receipt safeguards remain binding | CLEAR |
| design review | 1 | 0 | interaction, accessibility, and visual evidence plan reviewed | CLEAR |
| DevEx review | 1 | 0 | commands, staging isolation, failure paths, and contributor handoff reviewed | CLEAR |

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|---|---|---:|---:|---|---|
| CEO Review | `/plan-ceo-review` | Scope and strategy | 1 | CLEAR | Owner pre-approval resolved the historical-evidence ruling |
| Codex Review | `/codex` | Independent second opinion | 5 | CLEAR | All 19 findings closed; final targeted result `CLEAR` |
| Grok Review | `/grok` | Independent model review | 2 | CLEAR | Four contradictions closed; final targeted result `CLEAR` |
| MOA-equivalent | council fallback | Independent synthesis | 2 | CLEAR | Named `/moa` unavailable; bounded reviewers and root synthesis closed 12 findings |
| Eng Review | `/plan-eng-review` | Architecture and tests | 1 | CLEAR | Owner accepted the deviation; technical and evidence plan clear |
| Design Review | `/plan-design-review` | UI/accessibility completeness | 1 | CLEAR | No unresolved finding |
| DX Review | `/plan-devex-review` | Contributor execution clarity | 1 | CLEAR | No unresolved finding |

**VERDICT:** CLEARED FOR IMPLEMENTATION.

NO UNRESOLVED DECISIONS
