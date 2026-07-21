# Praxodoro Acceptance Trace Matrix

Status: normative pre-Atom-3.1 trace contract
Contract count: 57 EARS criteria, 12 separate assumptions, 122 stable OpenSpec scenarios, 21 implementation atoms
Source criteria: SPEC.md
Task graph: prd.json and OpenSpec tasks.md

A planned mapping is not completion evidence. A criterion becomes verified only when every owning
atom is done, its named validation profile has fresh evidence, and the evidence path is recorded in
prd.json. If a criterion spans atoms, earlier atoms may prove a component but must not claim the
whole criterion. The frozen profile column is the exact set of required proof modes. The planned
evidence-contributor column must equal the owning-atom column: every owner contributes its own
milestone evidence for its part of the oracle, even when another atom runs the final integrated test.

## Validation profiles

| Profile | Required proof |
|---|---|
| governance | strict OpenSpec, artifact/count checks, dependency integrity, clean Git scope |
| core-unit | deterministic Swift Testing with manual clocks and closed state/intent/error tables |
| repository-contract | identical contract suite against in-memory and temporary SwiftData adapters |
| app-integration | signed app tests for shared AppModel/container/platform adapter behavior |
| signed-ui | retained xcresult with executed XCUITest and accessibility identifiers |
| accessibility-manual | keyboard, VoiceOver, display accommodations, light/dark, resize matrix |
| privacy-static | source/entitlement/domain scans, schema/field snapshots, secret scan |
| privacy-runtime | isolated network capture, retention/export/delete/notification behavior |
| visual-regression | native screenshot/hierarchy comparison for full and fallback render policies |
| performance-energy | signposts/Instruments plus hidden, reduced-motion, and low-power assertions |
| fresh-validator | independent clean-context criterion-to-code/evidence audit |

## Stable OpenSpec scenario coverage

Scenario IDs are immutable trace keys. Titles may improve and scenarios may move, but an ID is never
renumbered or reused. `direct` means the scenario exercises the cited EARS behavior; `supporting`
means it narrows an OpenSpec design/detail without claiming to satisfy the EARS criterion alone.
Every OpenSpec scenario has exactly one row.

| Scenario ID | Scenario | EARS criterion link(s) | Relationship |
|---|---|---|---|
| AHC-S001 | Coach explanation | C-010 | direct |
| AHC-S002 | Start without capacity | C-001 | direct |
| AHC-S003 | Clear capacity | C-001 | direct |
| AHC-S004 | Manual first action | C-002 | direct |
| AHC-S005 | Deterministic breakdown | C-002 | direct |
| AHC-S006 | AI suggestion acceptance | C-002 | supporting |
| AHC-S007 | Detour suggestion reason | C-010 | direct |
| AHC-S008 | Due check-in choices | C-003 | direct |
| AHC-S009 | Ignored check-in | C-004 | direct |
| AHC-S010 | Cadence changes during session | C-003 | supporting |
| AHC-S011 | Park and return | C-006 | direct |
| AHC-S012 | Make smaller | C-002, C-006 | supporting |
| AHC-S013 | Suggested break | C-005 | direct |
| AHC-S014 | End break early | C-005 | direct |
| AHC-S015 | Return from break | C-006 | direct |
| AHC-S016 | Mode enabled | C-007 | direct |
| AHC-S017 | Relaunch in low-cognitive-load mode | C-007 | direct |
| AHC-S018 | Sparse observations | C-008 | direct |
| AHC-S019 | Eligible descriptive pattern | C-008 | direct |
| AHC-S020 | Intentional early stop | C-010 | direct |
| AHC-S021 | Pro capability requested during focus | C-009 | direct |
| EDC-S001 | Capability allowed | G-006 | supporting |
| EDC-S002 | Capability unavailable | G-002 | direct |
| EDC-S003 | Required Lite behavior | G-001 | direct |
| EDC-S004 | Lite feature matrix | G-001 | direct |
| EDC-S005 | Pro entitlement | G-002 | direct |
| EDC-S006 | Pro service unavailable | G-002 | direct |
| EDC-S007 | Enterprise admin schema | G-003 | direct |
| EDC-S008 | Managed privacy restriction | G-003 | direct |
| EDC-S009 | Entitled but permission denied | G-002 | direct |
| EDC-S010 | Enterprise distribution unavailable | G-003 | supporting |
| EDC-S011 | Unverified paid evidence | G-004 | direct |
| EDC-S012 | Static development evidence | G-004 | supporting |
| EDC-S013 | No production verifier in the first slice | G-004 | supporting |
| EDC-S014 | Pro expires during focus | G-005 | direct |
| EDC-S015 | Offline downgrade | G-004 | direct |
| EDC-S016 | Personal cadence is not managed | G-003 | supporting |
| EDC-S017 | Enforced privacy restriction | G-003 | supporting |
| EDC-S018 | Capability registry completeness | G-006 | direct |
| EDC-S019 | Capability change without session change | G-007 | direct |
| FSE-S001 | First session starts | E-001 | direct |
| FSE-S002 | Concurrent surface commands | E-002 | direct |
| FSE-S003 | Clean offline launch | E-001 | direct |
| FSE-S004 | Invalid resume intent | E-003 | direct |
| FSE-S005 | Completion enters review | C-010 | supporting |
| FSE-S006 | Break ends in explicit re-entry | C-006 | direct |
| FSE-S007 | Exhaustive state and intent behavior | E-003 | direct |
| FSE-S008 | Exact default manifest | G-001 | direct |
| FSE-S009 | Error classification | E-003, E-007, E-010 | supporting |
| FSE-S010 | Policy selection | G-001 | direct |
| FSE-S011 | Open-ended Flow policy | G-001 | direct |
| FSE-S012 | Countdown rendering | E-004 | direct |
| FSE-S013 | Pause snapshot | E-004 | direct |
| FSE-S014 | Duplicate completion signals | E-008 | direct |
| FSE-S015 | Wake before deadline | E-006 | direct |
| FSE-S016 | Wake after deadline | E-006 | direct |
| FSE-S017 | Relaunch during focus | E-007 | direct |
| FSE-S018 | Impossible post-restart clock value | E-007 | direct |
| FSE-S019 | Manual clock change while running | E-005 | direct |
| FSE-S020 | Second start request | E-009 | direct |
| FSE-S021 | Replace and review | E-009 | direct |
| FSE-S022 | Park a thought | C-006 | supporting |
| FSE-S023 | Persistence failure | E-010 | direct |
| FSE-S024 | Notification failure after commit | E-010 | direct |
| FSE-S025 | Pause from menu bar | U-009 | direct |
| LIE-S001 | Functional control surface | U-001 | direct |
| LIE-S002 | Reading surface | U-001 | direct |
| LIE-S003 | Timer instrument | U-001 | direct |
| LIE-S004 | Dependency audit | U-010 | direct |
| LIE-S005 | Future effect package proposal | U-010 | supporting |
| LIE-S006 | Reduce Transparency enabled | U-002 | direct |
| LIE-S007 | Reduce Motion enabled | U-003 | direct |
| LIE-S008 | Increased contrast | U-004 | direct |
| LIE-S009 | Differentiate Without Color | U-004 | direct |
| LIE-S010 | Hidden app with menu bar only | U-005 | direct |
| LIE-S011 | Low Power Mode | U-005 | direct |
| LIE-S012 | Pointer-free focus loop | U-006 | direct |
| LIE-S013 | Screen transition | U-006 | direct |
| LIE-S014 | Timer accessibility value | U-006 | direct |
| LIE-S015 | Energy/history chart | U-007 | direct |
| LIE-S016 | Narrow window with large text | U-008 | direct |
| LIE-S017 | Appearance change | U-008 | direct |
| LIE-S018 | Menu-bar parity | U-009 | direct |
| LIE-S019 | Compact surface | U-009 | direct |
| LIE-S020 | Visual regression review | D-003, D-005 | supporting |
| LDC-S001 | Data dictionary audit | P-001 | direct |
| LDC-S002 | Network loss during focus | P-002 | supporting |
| LDC-S003 | Offline network capture | P-002 | direct |
| LDC-S004 | Default retention manifest | P-009 | direct |
| LDC-S005 | Retention cleanup | P-009 | direct |
| LDC-S006 | Default completion cleanup | P-003 | direct |
| LDC-S007 | Private history opt-in | P-003 | supporting |
| LDC-S008 | Completed-sessions-only sync | P-001 | supporting |
| LDC-S009 | Sync unavailable or denied | G-002 | direct |
| LDC-S010 | Permission timing | P-004 | direct |
| LDC-S011 | Default preview | P-004 | direct |
| LDC-S012 | Event deduplication | P-004 | direct |
| LDC-S013 | System quiet settings | P-004 | supporting |
| LDC-S014 | Minimal export | P-005 | direct |
| LDC-S015 | Export after downgrade | P-005, G-004 | direct |
| LDC-S016 | Successful local delete all | P-006 | direct |
| LDC-S017 | Partial synced deletion | P-006 | direct |
| LDC-S018 | Exported files and backups | P-006 | direct |
| LDC-S019 | Diagnostic event | P-007 | direct |
| LDC-S020 | Permission and entitlement audit | P-008 | direct |
| LDC-S021 | Secret scan | P-010 | direct |
| LDC-S022 | Migration failure | P-010 | direct |
| MAD-S001 | Clean project generation | D-001 | direct |
| MAD-S002 | Clean command-line build | D-002 | direct |
| MAD-S003 | Target inventory | D-002 | supporting |
| MAD-S004 | Concurrency build | D-002 | direct |
| MAD-S005 | Repository contract suite | E-010, D-003 | supporting |
| MAD-S006 | Scene integration test | U-009 | direct |
| MAD-S007 | Task evidence | D-003 | supporting |
| MAD-S008 | Pull-request workflow | D-003, D-005 | direct |
| MAD-S009 | Local verification | S-002, D-003, D-005 | direct |
| MAD-S010 | XcodeGen provenance | D-001 | supporting |
| MAD-S011 | OpenSpec provenance | S-001 | direct |
| MAD-S012 | Unapproved dependency | D-005 | supporting |
| MAD-S013 | Fresh smoke launch | D-004 | direct |
| MAD-S014 | Fresh-context acceptance audit | S-003, D-006 | direct |
| MAD-S015 | Local completion | D-007 | direct |

## Criterion trace

| ID | OpenSpec requirement / scenario | Owning atom(s) | Frozen profile(s) | Planned evidence contributor(s) | Proof oracle |
|---|---|---|---|---|---|
| S-001 | Pinned development dependencies / OpenSpec provenance | 8.1 | governance | 8.1 | official OpenSpec source/license/integrity/purpose/upgrade/removal plus clean-install verifier |
| S-002 | Full verification workflow / Local verification | 8.1 | governance | 8.1 | strict validation JSON with six specs, design, and tasks |
| S-003 | Documentation and durable workflow state / Fresh-context resume | 8.2 | fresh-validator | 8.2 | new-agent resume from repository artifacts only |
| E-001 | One canonical active session / First session starts; Offline no-prerequisite start / Clean offline launch | 3.1, 3.2, 4.1, 4.2, 5.3 | core-unit, signed-ui | 3.1, 3.2, 4.1, 4.2, 5.3 | valid offline start, canonical persistence, and no prerequisite takeover |
| E-002 | One canonical active session / Concurrent surface commands | 4.1, 5.2 | core-unit, app-integration | 4.1, 5.2 | concurrent commands serialize to one revision across both surfaces |
| E-003 | Explicit lifecycle state machine / Invalid resume intent | 3.1, 3.2, 4.1 | core-unit | 3.1, 3.2, 4.1 | closed types, exhaustive unlisted-pair rejection, and engine preservation |
| E-004 | Canonical timestamp projection / Countdown rendering | 3.1, 3.2, 3.3, 5.3, 7.2 | core-unit, performance-energy | 3.1, 3.2, 3.3, 5.3, 7.2 | projection shape, reducer materialization, zero-write arithmetic, surface cadence, and energy proof |
| E-005 | In-process wall-clock adjustment / Manual clock change while running | 3.2, 3.3, 4.1 | core-unit | 3.2, 3.3, 4.1 | pure drift decision, factual adjustment candidate, and serialized commit in both directions |
| E-006 | Sleep and wake reconciliation / Wake before deadline; Wake after deadline | 3.2, 3.3, 4.1 | core-unit | 3.2, 3.3, 4.1 | pure wake decision, one-boundary reducer mapping, and no overdue auto-chain through the actor |
| E-007 | Relaunch recovery / Relaunch during focus; Impossible post-restart clock value | 3.2, 3.3, 4.1, 4.2 | core-unit, repository-contract | 3.2, 3.3, 4.1, 4.2 | pure recovery decision, restore/recovery candidate, serialized bootstrap, and persisted restore contract |
| E-008 | Exactly-once phase boundary / Duplicate completion signals | 3.2, 3.3, 4.1 | core-unit | 3.2, 3.3, 4.1 | admission decision, duplicate/stale reducer mapping, and same token committing once through the actor |
| E-009 | Active-session conflict resolution / Second start request; Replace and review | 3.2, 5.3 | core-unit | 3.2, 5.3 | reducer choices plus reachable Resume, Replace and Review, and Cancel UI |
| E-010 | Atomic commit before effects / Persistence failure; Notification failure after commit | 4.1, 4.2, 6.2 | repository-contract, app-integration | 4.1, 4.2, 6.2 | engine order, adapter atomicity, and notification failure preservation |
| C-001 | Capacity optional and uninferred / Start without capacity; Clear capacity | 3.2, 5.3 | core-unit, signed-ui | 3.2, 5.3 | nil semantics and Not specified UI with no inferred capacity reason |
| C-002 | Editable deterministic first action / Manual first action; Deterministic breakdown | 3.2, 5.3 | core-unit, signed-ui | 3.2, 5.3 | AI-off fallback and explicit initiation accept/edit path |
| C-003 | User-steerable check-ins / Due check-in choices | 3.2, 5.4 | core-unit, signed-ui | 3.2, 5.4 | all six semantic actions in reducer and native check-in surface |
| C-004 | User-steerable check-ins / Ignored check-in | 3.2, 5.4 | core-unit, signed-ui | 3.2, 5.4 | one resolved occurrence with no penalty, escalation, or duplicate UI |
| C-005 | Explainable optional breaks / Suggested break; End break early | 3.2, 5.4 | core-unit, signed-ui | 3.2, 5.4 | typed reasons, alternatives, disable, quiet, and early end |
| C-006 | Re-entry preserves orientation / Return from break | 3.2, 5.4 | core-unit, signed-ui | 3.2, 5.4 | task, action, and thoughts restored before explicit resume |
| C-007 | Low-cognitive-load focus mode / Mode enabled; Relaunch in mode | 4.2, 5.3, 7.1 | signed-ui, accessibility-manual | 4.2, 5.3, 7.1 | persisted setting, reduced hierarchy, and final accessibility matrix |
| C-008 | Descriptive evidence-aware review / Sparse observations; Eligible descriptive pattern | 5.4, 6.1 | core-unit, signed-ui | 5.4, 6.1 | threshold UI plus retained 5-observation and 3-day data boundary |
| C-009 | No commerce in vulnerable flow states / Pro capability requested during focus | 3.2, 5.2, 5.4 | core-unit, signed-ui | 3.2, 5.2, 5.4 | core rejection/routing, shared capability state, and non-blocking UI |
| C-010 | Non-clinical positioning; No punitive/coercive design / Intentional early stop | 3.2, 5.3, 5.4 | core-unit, signed-ui | 3.2, 5.3, 5.4 | transition semantics, copy snapshots, and prohibited-phrase scan |
| G-001 | Lite complete differentiated core / Lite feature matrix | 2.1, 3.1, 3.2, 3.3, 4.1, 4.2, 5.1, 5.2, 5.3, 5.4, 5.5, 6.1, 6.2, 6.3, 7.1, 7.2 | core-unit, app-integration, signed-ui, accessibility-manual, privacy-static, privacy-runtime | 2.1, 3.1, 3.2, 3.3, 4.1, 4.2, 5.1, 5.2, 5.3, 5.4, 5.5, 6.1, 6.2, 6.3, 7.1, 7.2 | full Lite behavior inventory across every implementation owner |
| G-002 | Pro depth without weakening Lite / Pro entitlement; Pro service unavailable | 2.1, 2.2 | core-unit | 2.1, 2.2 | exact superset plus independent unavailable reasons |
| G-003 | Enterprise managed deployment / Enterprise admin schema | 2.2 | core-unit, privacy-static | 2.2 | exhaustive managed/audit fields with no personal behavior fields |
| G-004 | Verifiable evidence / Unverified paid evidence; Downgrade / Offline downgrade; Export after downgrade | 2.2, 5.2, 6.3 | core-unit, app-integration, privacy-runtime | 2.2, 5.2, 6.3 | fail-closed resolver, combined-app runtime Lite fallback, and Lite-after-Pro reads/export |
| G-005 | Downgrade / Pro expires during focus | 2.2, 5.2 | core-unit, app-integration | 2.2, 5.2 | expiry-only lease resolution plus next-boundary gating in the combined session/capability model |
| G-006 | Edition changes testable / Capability registry completeness | 2.1, 2.2 | core-unit | 2.1, 2.2 | descriptor and environment-dimension exhaustiveness |
| G-007 | Edition changes observable / Capability change without session change | 5.2 | app-integration | 5.2 | capability-only publication preserves session ID and revision |
| U-001 | Semantic surface roles / Functional control, reading surface, timer instrument | 5.1, 5.3, 7.1 | visual-regression, accessibility-manual | 5.1, 5.3, 7.1 | semantic roles, focus-surface use, and final hierarchy/legibility audit |
| U-002 | Automatic reduced transparency / Reduce Transparency enabled | 5.1, 7.1 | visual-regression, signed-ui | 5.1, 7.1 | render policy and executed fallback with every action intact |
| U-003 | Automatic reduced motion / Reduce Motion enabled | 5.1, 7.1 | visual-regression, performance-energy | 5.1, 7.1 | render policy plus motion and remaining-opacity timing proof |
| U-004 | Contrast and non-color differentiation / Increased contrast; Differentiate Without Color | 5.1, 7.1 | visual-regression, accessibility-manual | 5.1, 7.1 | token redundancy and final border/icon/shape/text inspection |
| U-005 | Low-power and visibility policy / Hidden app; Low Power Mode | 5.1, 7.1, 7.2 | performance-energy | 5.1, 7.1, 7.2 | render policy, final UI audit, and measured renderer/signpost inactivity |
| U-006 | Keyboard-complete and VoiceOver-semantic operation / Pointer-free loop; Screen transition; Timer value | 5.2, 5.3, 5.4, 5.5, 7.1 | signed-ui, accessibility-manual | 5.2, 5.3, 5.4, 5.5, 7.1 | shared model plus reachable actions and once-only announcements on every surface |
| U-007 | VoiceOver-semantic operation / Energy/history chart | 5.4, 7.1 | signed-ui, accessibility-manual | 5.4, 7.1 | equivalent ordered values, time context, and final assistive audit |
| U-008 | Resizable appearance-aware layout / Narrow window with large text; Appearance change | 5.1, 5.3, 7.1 | visual-regression, accessibility-manual | 5.1, 5.3, 7.1 | adaptive tokens, focus layout, and minimum-size/scale/appearance matrix |
| U-009 | One hierarchy across surfaces / Menu-bar parity; Compact surface | 5.2, 5.5, 7.1 | app-integration, signed-ui | 5.2, 5.5, 7.1 | shared state, compact/menu-bar surface parity, and final UI execution |
| U-010 | Native-first effects / Dependency audit | 5.1, 7.2 | privacy-static, governance | 5.1, 7.2 | native render implementation and final runtime/network-font dependency audit |
| P-001 | Sensitive data classification / Data dictionary audit | 4.2, 6.1 | privacy-static | 4.2, 6.1 | persisted schema plus field purpose/default/retention/sync/export/delete manifest |
| P-002 | Zero-network Lite baseline / Offline network capture | 7.2 | privacy-runtime | 7.2 | isolated Lite capture records zero outbound requests |
| P-003 | Session-only capacity/check-ins / Default completion cleanup | 4.2, 6.1 | repository-contract, privacy-runtime | 4.2, 6.1 | storage behavior and retention cleanup remove raw answers after completion |
| P-004 | Privacy-safe notifications / Permission timing, Default preview, Event deduplication | 6.2 | app-integration, privacy-runtime | 6.2 | no eager permission, private preview, and one delivered event |
| P-005 | Complete selectable export / Minimal export; Export after downgrade | 6.3 | privacy-runtime | 6.3 | exact selected fields and Lite-after-Pro export |
| P-006 | Honest complete deletion / Local delete all; Partial synced deletion; Exported files/backups | 6.3 | repository-contract, privacy-runtime | 6.3 | zero local queries and honest remaining-copy state |
| P-007 | Content-free diagnostics / Diagnostic event | 6.2, 7.2 | privacy-static, privacy-runtime | 6.2, 7.2 | bounded content-free emitter plus final source and network capture audit |
| P-008 | No surveillance or advertising / Permission and entitlement audit | 7.2 | privacy-static, fresh-validator | 7.2 | prohibited API, entitlement, and domain absence |
| P-009 | Bounded default retention / Default manifest; Retention cleanup | 4.2, 6.1 | repository-contract, privacy-runtime | 4.2, 6.1 | stored retention fields plus 24h/session/7d/30d/90d/ephemeral cleanup boundaries |
| P-010 | Secret and migration hygiene / Secret scan; Migration failure | 4.2, 6.1, 6.3 | repository-contract, privacy-static | 4.2, 6.1, 6.3 | recoverable schema, data-policy boundary, export/delete boundary, and secret scan |
| D-001 | Native reproducible project / Clean project generation | 1.1, 1.2, 8.1 | governance | 1.1, 1.2, 8.1 | pinned generator, recursive no-diff gate, and final CI execution |
| D-002 | Strict concurrency / Concurrency build | 1.2, 5.2, 8.1 | governance, app-integration | 1.2, 5.2, 8.1 | strict build settings, shared actor integration, and final CI execution |
| D-003 | Full verification workflow / Pull-request workflow; Local verification | 8.1, 8.2 | governance | 8.1, 8.2 | mandatory local/CI suites plus final evidence reconciliation |
| D-004 | Deterministic launch smoke / Fresh smoke launch | 1.1, 8.1, 8.2 | signed-ui, governance | 1.1, 8.1, 8.2 | scaffold smoke, final isolated launch, and fresh-context rerun |
| D-005 | Full verification workflow / Pull-request workflow; Local verification | 7.2, 8.1, 8.2 | governance, privacy-runtime, performance-energy | 7.2, 8.1, 8.2 | privacy/energy gates, mandatory orchestration, and final no-skip audit |
| D-006 | Fresh-context validator gate | 8.2 | fresh-validator | 8.2 | all 57 rows point to current code/evidence or an explicit incomplete owner |
| D-007 | Shipping boundary honesty / Local completion | 8.2 | fresh-validator | 8.2 | performed versus unperformed remote, signing, notarization, cloud, commerce, and service matrix |

## Cross-atom completion rule

- G-001 remains incomplete until its full owner set passes: the capability inventory alone does not
  prove the runtime, coach, native surfaces, accessibility, privacy, export/delete, or zero-network
  Lite behavior.
- G-004 is intentionally not complete at Atom 2.2: 5.2 must integrate runtime fallback without
  contaminating the pure session engine, and 6.3 must prove local reads/export after downgrade.
- G-005 is completed only when Atom 5.2 binds Atom 2.2's opaque expiry-only lease decision to the
  shared session/capability projection and proves gating changes at the next committed boundary.
- G-007 is intentionally owned only by 5.2: entitlement resolution does not prove observable app
  publication.
- E-010 spans reducer/engine, repository, and notification atoms; a successful core test is not the
  full criterion.
- U-006 and U-009 span multiple native surfaces and final accessibility QA.
- D-003 through D-007 remain final-gate criteria even when earlier atoms provide component evidence.

Any future criterion, scenario, or atom must update this matrix, SPEC.md counts, prd.json mappings,
and the fresh-validator checks in the same reviewed change.
