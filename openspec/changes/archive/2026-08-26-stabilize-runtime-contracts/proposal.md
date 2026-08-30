# Proposal: stabilize-runtime-contracts

## Why

The deterministic timer engine is already the right foundation, but three runtime boundaries still rely on convention instead of contracts:

- transition events are written and decoded through repeated string literals, and an unknown stored transition currently becomes `running`;
- the end of a break is derived separately by Core, sound, and notifications;
- a main surface can mutate routing state directly instead of expressing an intent through `AppModel`.

The approved enterprise-grade plan records these as prerequisite issues #51, #52, and #53. They must land before schema migration (#37), event editing (#21), and review reconstruction (#22), because those changes would otherwise build on ambiguous payloads and duplicated time arithmetic.

## Goals, non-goals, assumptions

**Goals:** define one transition-payload codec over Core's existing `SessionState`; extract pure store-to-Core reconstruction behind `SessionReplay`; reject unsupported lifecycle states, unknown transition payloads, and malformed adjustments with typed errors; keep replay application atomic after a complete input fetch; derive a break's canonical end instant once in Core; route surface navigation through a model intent; leave executable compiler and source guards for those boundaries.

**Non-goals:** an injectable store-failure seam or store recovery presentation (#35), persist-before-mutate and the observable error channel (#36), `VersionedSchema` (#37), a broad `AppModel` decomposition, migration of every main surface to an actions struct, new settings or timer behavior, persistence-schema changes, network capability, or product-tier work.

**Assumptions:** the existing string payloads `running`, `held`, `break`, and `closed` are durable on-disk vocabulary; `PraxmodoroStore` remains independent of `PraxmodoroCore`; the app target is the only existing layer allowed to import both packages; `TimingPolicy.suggestedBreak` remains the ordinary break length. Core's time-shaped `autoReturn: TimeInterval?` argument has no independent duration policy in the app and is migrated explicitly to `autoReturn: Bool` so it cannot remain a second duration authority. A separate `autoReturnAfter` instant records when the current process began live observation; it is required to distinguish witnessed sleep/wake from an absent relaunch interval.

**Product/capability impact:** no feature is added or removed. The replay boundary returns a typed error instead of fabricating focus time from an unknown record; the current launch caller still suppresses restore errors until #35/#36 add user presentation. Sound, notification, and engine return behavior become anchored to the same instant, and auto-return occurs only for a break end the current process was alive to witness.

**Measurable success:** all issue #51–#53 acceptance criteria have red-then-green evidence; `AppModel` has exactly one direct transition-event append site and every lifecycle write routes through it; `AppModel.surface` is `private(set)` and no surface assigns it; a cadence-boundary agreement test proves the break-end chime, notification, and materialized return share one instant; process-boundary tests prove witnessed sleep returns once while a break end before launch never catches up; `./scripts/verify-project.sh`, `./scripts/smoke.sh`, and `npm run spec:validate` exit 0; independent specification and code-review findings are closed before commit.

## What Changes

- **App replay boundary:** add one app-target file containing the lifecycle payload codec, replay result, typed replay errors, and `SessionReplay.replay(events:task:)`. `AppModel.restore()` becomes store I/O plus application of the pure replay result.
- **App event writes and review labels:** one `AppModel.appendTransition(_:at:)` helper owns the only direct transition append; every writer uses it; review labels decode through the same vocabulary; an unknown review record is labelled explicitly.
- **Core break boundary:** add `Session.breakEndInstant(cadence:)`, migrate `reconciled(autoReturn:)` from a duration-shaped optional to an explicit Boolean gate plus `autoReturnAfter` process-live fence, and make AppModel reconciliation, sound, and notifications consume the Core instant. The settings remediation subsequently wires the existing root observation edge to materialize that bounded reconciliation.
- **Surface intent boundary:** make `AppModel.surface` read-only outside the model, add `AppModel.beginNextSession()`, and replace the review surface's direct routing write; retain a source guard as a readable architecture check.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `session-persistence`: gains a single lifecycle payload and replay contract at the app integration boundary.
- `timer-engine`: gains a canonical, cadence-aware break-end instant consumed by all schedulers and reconciliation.
- `focus-loop-ui`: requires surfaces to express routing intents through `AppModel` methods rather than assign model state.
