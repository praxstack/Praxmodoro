# Runtime contract foundation implementation plan

Date: 2026-08-23
Branch: `prax/architecture-review-2026-08-23`
Baseline: `a78e0e04cbf5cfe75582e50bfd0ec6b2afb0a4e7`
OpenSpec change: `stabilize-runtime-contracts`
Issues: #51, #52, #53
Status: complete 2026-08-26; archived as `2026-08-26-stabilize-runtime-contracts`; post-archive Core 46/46 and full signed gate passed

## Objective

Make the smallest architecture change that removes three verified sources of drift before persistence migration and timeline work: implicit event strings, three break-end calculations, and direct view routing mutation.

Success means the app behaves the same for valid data, returns typed replay errors instead of inventing state, supplies the Core/AppModel boundary that settings task 10.7 later uses for witnessed-sleep and relaunch-absence behavior, and leaves compiler-enforced plus executable guards proving the three runtime boundaries. User-facing restore error presentation remains owned by #35/#36; root observation behavior and wiring remain owned by settings 10.7.

## Frozen evidence

- Fresh `./scripts/verify-project.sh` exited 0 with `verify-project: OK` before this plan was drafted.
- `PraxmodoroCore` derives remaining time from transitions and canonical timestamps; no timer rewrite is required.
- `AppModel.restore()` maps unknown transition payloads to `.running`.
- Break end is assembled in two `AppModel` scheduling paths and one Core reconciliation path.
- `ReviewSurface` directly assigns `model.surface`.
- Issues #51–#53 are open and labelled `ready-for-agent`; this plan reuses them and creates no duplicate ticket.

## Scope decision

The owner-approved 2026-08-23 enterprise-grade plan selected Approach B, a trust pass, and delegated autonomous sequencing. This plan is the prerequisite rung for that approved direction.

### Alternative A: Inline patch

Replace strings and repeated expressions in place. This is smaller in raw lines but leaves replay inside `AppModel` and cannot make Store-to-Core reconstruction independently testable.

### Alternative B: Narrow contracts (selected)

One app replay/payload file, one Core method, one model intent, and source guards. This solves all three approved prerequisite tickets without a package or framework.

### Alternative C: Controller decomposition

Split `AppModel` into multiple services and action protocols. Deferred because no current requirement needs those abstractions and issue #53 explicitly records the broader migration as out of scope.

## Architecture after the change

```text
Surfaces --intents--> AppModel --encoded transition--> LocalStore
                         ^                              |
                         |                              v
                         +-- replay result -- SessionReplay
                                                |
                                                v
                                          Core Session
                                                |
                       +------------------------+------------------------+
                       v                        v                        v
       auto-return + live fence      break-end sound          break-end notification
                       \________________ same instant __________________/
```

## Implementation order

### Phase 1: Specification approval

1. Strict-validate the OpenSpec change.
2. Run spec-creator self-review.
3. Run Codex, Grok, MOA-equivalent council, independent subagent, CEO, engineering, design, and DevEx plan reviews.
4. Fix all critical/major findings and any actionable minor inconsistency.
5. Repeat strict validation. Production code remains untouched until this phase is green.

### Phase 2: Payload and replay boundary (#51)

1. Add failing replay and source-guard tests in `LifecycleTests.swift`, including rejection of a second direct transition append and bare lifecycle payload literals on write paths.
2. Observe the expected failures.
3. Add `SessionReplay.swift` with a strict codec over Core `SessionState`, replay result, and typed errors.
4. Make `focused.sh` run the existing `scripts/generate.sh` unconditionally, then regenerate before the first green build so the new file is present in the generated project. The `.xcodeproj` remains ignored and uncommitted.
5. Add the sole transition-append helper and replace only `AppModel` replay, transition writes, and transition review labels.
6. Run focused tests and the ephemeral-store smoke test.

### Phase 3: Canonical break end (#52)

1. Add failing Core derivation tests and one app agreement test.
2. Observe the missing-method/agreement failure.
3. Add `Session.breakEndInstant(cadence:)` and migrate `reconciled(autoReturn:)` to an explicit Boolean gate with an `autoReturnAfter` process-live fence.
4. Make Core reconciliation, AppModel boundary plumbing, sound, and notifications consume it; settings task 10.7 later owns root observer behavior and wiring.
5. Run Core, focused, and smoke checks.

### Phase 4: Surface intent boundary (#53)

1. Add failing behavior and source-scan tests in `SurfaceTests.swift`.
2. Observe the missing method and direct-write violation.
3. Make `AppModel.surface` `private(set)`, add `beginNextSession()`, and call it from `ReviewSurface`.
4. Run focused and smoke checks.

### Phase 5: Review, evidence, and commits

1. Run the named code-review workflow and an independent fresh-context implementation validator over the complete uncommitted diff.
2. Fix every finding and repeat both reviews until clean.
3. Run Core tests, Store tests, focused tests, full project verification, smoke, and strict OpenSpec validation from a fresh shell.
4. Commit each implementation atom separately only after its exact staged tree passes focused checks in a temporary detached worktree created from `git write-tree`; record whole-diff and residual-patch SHA-256 receipts.
5. Update active tasks, `prd.json`, and `progress.txt` with observed evidence and atom SHAs, then dispatch a fresh-context validator over the committed implementation plus those uncommitted receipts. A production/test finding re-enters red regression, minimal repair, code/adversarial review, fresh gates, isolated staged-tree proof, scoped repair commit, evidence update, and revalidation; documentation-only fixes still rerun strict validation. Require COMPLETE and never hide implementation in the archive commit.
6. Archive the OpenSpec change, re-run final gates, and commit archive/evidence as the final scoped commit.
7. Reconcile #51–#53 only when that final committed evidence exists; narrow #53's ambiguous acceptance wording to the approved `model.surface` boundary rather than expanding this change.

## Error and recovery map

| Boundary | Failure | Required outcome |
|---|---|---|
| replay | unsupported idle write or unknown lifecycle payload | typed error; no event or `.running` fallback; no partial activation |
| replay | malformed adjustment | typed error; no silent drop; no partial activation |
| store fetch | SwiftData read error before all replay inputs are available | propagate existing error; do not invoke replay or claim anything about partial fetch/storage effects; this change adds no store-failure seam or store-boundary atomicity guarantee, which remain #35/#36 scope |
| break derivation | not on break | return `nil`; schedule nothing; materialize nothing |
| surface routing | direct assignment introduced | source test fails before merge |

## Test map

| Contract | Red test | Green proof |
|---|---|---|
| known replay | lifecycle round trip through `SessionReplay` | session state, task, thoughts, adjustments equal persisted values; closed result returned but not activated |
| invalid replay | unknown transition, malformed adjustment, unsupported idle | exact typed error; sentinel model state remains byte-for-byte unchanged |
| payload writes | source scan | exactly one direct transition append, inside the codec-backed helper; no bare durable lifecycle literal on any write path |
| generated project freshness | add `SessionReplay.swift` while an existing project omits it | `focused.sh` regenerates before build; new source compiles; `.xcodeproj` remains ignored |
| break end | Core ordinary/cadence/nil and before/after process-boundary cases | one method returns the expected instant; absent breaks never catch up and witnessed sleep does |
| three consumers | app agreement case | sound == notification == return transition instant |
| surface intent | compiler boundary, review action, source scan | `surface` is `private(set)`; route changes through method; zero direct surface assignments |

## Rollback and stop rules

- Rollback pointer: `a78e0e04cbf5cfe75582e50bfd0ec6b2afb0a4e7`.
- No schema migration occurs, so rollback requires no data transform.
- Stop before implementation if any spec reviewer finds an unresolved critical/major issue.
- Stop before commit if any code reviewer finding remains open or any required command exits nonzero.
- Do not weaken a test, change `SPEC.md` acceptance thresholds, or broaden into #35–#40 or the deferred actions migration to obtain green output.

## Review ledger

| Reviewer | Run | Findings | Resolution | Status |
|---|---:|---:|---|---|
| spec-creator self-review | 2 | 4 | corrected verification scan, concrete replay types, atomic restore, archive ordering; final strict recheck passed | CLEAR |
| Codex | 5 | 19 across the umbrella review | runtime ownership, semantics, test, and delivery findings closed; final targeted recheck returned `CLEAR` | CLEAR |
| Grok | 2 | 4 across the umbrella review | runtime dependencies and cross-change wording reconciled; final targeted recheck returned `CLEAR` | CLEAR |
| MOA-equivalent council | 2 | 12 overlapping umbrella findings | independent bounded reviews plus root synthesis incorporated every finding | CLEAR |
| independent subagent | 3 | 7 | Boolean auto-return API, sentinel/closed restore tests, codec reuse, Core guard, active-change gate, archive evidence, and final ownership recheck | CLEAR |
| CEO review | 1 | 1 P1 governance decision | owner pre-approval resolved the umbrella settings-history ruling | CLEAR |
| engineering review | 1 | 1 P1 evidence decision | owner accepted the deviation; evidence safeguards remain binding | CLEAR |
| design review | 1 | 0 | no unresolved finding | CLEAR |
| DevEx review | 1 | 0 | no unresolved finding | CLEAR |

## GSTACK REVIEW REPORT

| Review | Runs | Status | Findings |
|---|---:|---|---|
| Codex | 5 | CLEAR | Final targeted result `CLEAR` |
| Grok | 2 | CLEAR | Final targeted result `CLEAR` |
| MOA-equivalent council | 2 | CLEAR | Named `/moa` unavailable; bounded fallback synthesis clear |
| CEO | 1 | CLEAR | Owner pre-approval resolved the umbrella governance ruling |
| Engineering | 1 | CLEAR | Owner accepted the deviation; evidence plan clear |
| Design | 1 | CLEAR | No unresolved finding |
| DevEx | 1 | CLEAR | No unresolved finding |

VERDICT: CLEARED FOR IMPLEMENTATION

NO UNRESOLVED DECISIONS
