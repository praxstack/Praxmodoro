# Praxmodoro — stages, scopes, phases, and the design-parity gap

Audit date 2026-08-04 · branch `feat/m2-companion-surfaces` @ `057a563` · method: local deep research, four parallel evidence shards over the mock sources, the Swift sources, the OpenSpec artifacts and the append-only decision record. Every claim below is traceable to a file and line.

No web research was used. Nothing outside this repository can testify about why this repository diverges from its own mocks.

---

## 1. Executive summary

The **behavioural** product is in good shape. The **perceptual** product barely exists.

The timer engine, the state machine, the persistence layer, the accessibility branches and the physics maths are faithful, tested and in several places golden-exact to 1e-9. The visual and interactive language that was actually approved on 2026-07-30 — the warm dusk-light room, three typefaces, layered depth, hover and press feel, the ripple, the acknowledgement bloom — is between 0% and 25% delivered.

The single-sentence cause: **nothing ever made visual fidelity testable, and this project only builds what its tests demand.**

Three findings go beyond "unfinished polish" and are defects against the written specification:

| # | Defect | Status claimed | Reality |
|---|---|---|---|
| D1 | The in-app **"Motion: still"** toggle is required by `SPEC.md:19` and by an EARS scenario at `openspec/specs/focus-loop-ui/spec.md:72`. No such control exists in `app/Sources`. Only the OS-level setting is read. | M1 gate 5 PASS | Requirement has no implementation |
| D2 | **Check-in acknowledgement pulse.** EARS scenario "Choice acknowledgement" requires the field to bloom when an answer is chosen. `CheckinSurface.swift:21` does not forward `pulseSignal`. | M1 validator flagged this; `progress.txt` records it fixed | Fixed at the model layer only; the surface still drops it |
| D3 | **`lastCheckinResponse`** is computed and stored (`AppModel.swift:114,144`) and read by nothing. The mock renders a live per-answer response. | — | Dead code standing in for a missing behaviour |

D2 is the most uncomfortable, because the M1 independent validator caught exactly this class of bug, the fix was recorded as complete, and the fix was incomplete. A test asserting `model.fieldPulse == before + 1` passes whether or not any surface listens.

---

## 2. Stages, scopes and phases

### 2.1 Milestone ladder

| Milestone | Scope | Governing change | Status |
|---|---|---|---|
| **M1** | App scaffold + complete core loop | `add-app-scaffold-core-loop`, archived `2026-07-31-…` | **COMPLETE 2026-07-31**, 7/7 gates, independently validated at `d56949d` — but see D1/D2 |
| **M2** | Companion surfaces + M1 hardening follow-ups | `add-companion-surfaces` (active) | **Implemented, 3 of 6 gates blocked** |
| **M3** | Staged integrations — EventKit import, App Intents, richer local analytics | none | Not specified |
| **M4** | Optional sync — CloudKit history, never live ticks | none | Not specified |
| **M5** | Edition content — Pro insights/automations, Enterprise policy boundaries | none | Not specified |

### 2.2 Capability specs

Canonical (`openspec/specs/`), synced when M1 archived:

| Capability | Requirements | Scenarios |
|---|---|---|
| `app-scaffold` | 6 | 9 |
| `timer-engine` | 6 | 11 |
| `focus-loop-ui` | 9 | 16 |
| `session-persistence` | 6 | 7 |
| **Total** | **27** | **43** |

M2 delta (`openspec/changes/add-companion-surfaces/specs/`):

| Capability | Mode | Requirements | Scenarios |
|---|---|---|---|
| `companion-surfaces` | ADDED | 6 | 19 |
| `focus-loop-ui` | MODIFIED | 1 | 6 |
| `session-persistence` | MODIFIED | 1 | 3 |
| `app-scaffold` | MODIFIED | 1 | 3 |
| **Total** | | **9** | **31** |

### 2.3 M2 phases (atoms)

| Atom | Scope | Status |
|---|---|---|
| g1 | `focused.sh` + `smoke.sh` + README | done |
| g2 | `SessionSnapshot` — one canonical session state | done |
| g3 | `SurfacePalette` + render-level a11y probes | done |
| g4 | Menu-bar popover | done (after 1 validator FAIL + 2 repairs) |
| g5 | Floating focus capsule | done |
| g6 | Return overlay | done |
| g7 | Motion standdown + VoiceOver on companion surfaces | done |
| g8 | Hardening — ⌘K, live schema parity, keyboard UI, first-run | **blocked** (UI half) |
| g9 | Full gauntlet, archive, whole-goal validation | **blocked** |
| `repair-344344ffb34b6bb1` | The no-second-clock guard | done |

M1: 28 atoms, all done, preserved under `prd.json → archivedMilestones`.

### 2.4 M2 gate status

| Gate | Requirement | Status |
|---|---|---|
| 1 | Every EARS scenario covered by a passing test | met, with the D1/D2 caveats |
| 2 | Three surfaces, one canonical engine-derived state | met — after **five** independent defeats of the guard, each closed |
| 3 | Four M1 hardening follow-ups | 2 of 4 met; keyboard-UI and first-run **blocked** |
| 4 | Accessibility alternates ship with the feature | met at the level tested |
| 5 | `verify-project.sh` exits 0 | **blocked** |
| 6 | Independent validator returns COMPLETE | **blocked** |

**Why 3, 5 and 6 are blocked:** XCUITest cannot initialize while the Mac's screen is locked (`LocalAuthentication -4`; `ioreg` reports `CGSSessionScreenIsLocked = true`). The suite compiles (`** TEST BUILD SUCCEEDED **`) but has never executed. Unblock: unlock the Mac, run `./scripts/verify-project.sh`.

### 2.5 Verification inventory

73 unit tests across 21 files · 6 UI tests across 2 files, **0 ever executed** · PraxmodoroCore 12 · PraxmodoroStore 7 · strict format lint clean · `spec:validate` 5/5 strict · `smoke.sh` exit 0.

---

## 3. Parity analysis

Status key: **ported** = faithful · **approx** = present but degraded · **absent** = nothing.

### 3.1 Physics — the one genuinely faithful layer

| Element | Evidence | Status |
|---|---|---|
| Spring integrator, asymmetric breath (3.6/1.2/5.4/1.4s), incommensurate drift | `FieldPhysics.swift`, golden-tested 1e-9 at `FieldPhysicsGoldenTests.swift:56-73` | **ported** |
| All 6 states — gathering, breathing, held, ripple, expanded, settled | `FieldPhysics.swift:69-75`; all reachable, no dead states | **ported** |
| All 5 layers with gain/phase/wander | `FieldPhysics.swift:85-91` | **ported** |
| Pointer lean springs | `companion-physics.js:97-98,142-151` — zero `lean` references in Swift | **absent** |
| Per-instance random breath phase and seed | JS randomises per field; no Swift surface passes `seed:`, all start identical | **absent** |
| rAF loop / dt clamp | `TimelineView(.animation)`, `min(0.05, …)` matches JS | approx |

The maths was ported with real rigour. What was not ported is everything that turns maths into a *feeling*.

### 3.2 Motion and effects — near-total absence

Counted across all of `app/Sources`:

| Construct | Occurrences |
|---|---|
| `withAnimation` | **0** |
| `.animation(` | **0** |
| `.transition(` | **0** |
| `matchedGeometryEffect` | **0** |
| `onHover` | **0** |
| `.shadow(` | **0** |

| Mock motion | Source | Status |
|---|---|---|
| `ripple-ring` expanding pulses — the defining visual of the check-in state | `mockups.css:538-541,559-572` | **absent** |
| `screen-enter` (opacity + translateY + scale, 500/675ms) | `mockups.css:342-351` | **absent** |
| 13 button/panel `transition:` rules | `mockups.css` | **absent** |
| `--dur-*` / `--ease-*` tokens (3 easings, 6 durations) | `tokens.css:92-101` | **absent** — no Swift equivalent exists |
| `motion-dot-pulse` | `mockups.css:290-293` | **absent** |
| Hover, `:active` translateY press feedback, custom focus rings | `mockups.css:45-49,153-161,264-269` | **absent** — stock SwiftUI defaults only |

Screen changes are a bare `switch` (`PraxmodoroApp.swift:32-38`); the return overlay appears via a plain `if` in `.overlay {}` with no transition.

**Acknowledgement pulse — wired at the model, dropped at the surface.** The JS kicks the pulse on five trigger classes. `AppModel` increments `fieldPulse` on three (`:143` answer, `:186` break choice, `:202` return acknowledgement) and never on `toggleHold()`/`begin()`. Of seven `CompanionFieldView(` call sites, **only two forward `pulseSignal`** — `FocusSurface.swift:35` and `BreakSurface.swift:21`. `CheckinSurface`, `ReturnOverlay`, `MenuBarPopover`, `FocusCapsule` and `ReviewSurface` all omit it. Net: roughly one of five intended blooms is visible.

### 3.3 Visual system

| Dimension | Mock | App | Ported |
|---|---|---|---|
| Colour tokens | 37 oklch (`tokens.css:5-41`) | 8 hardcoded sRGB literals | ~22%, eyeballed |
| Typefaces + type scale | Gabarito / Hanken Grotesk / Sono, 9 steps | system SF only; no `Font.custom`, no font files, no resource entry in `project.yml` | **0%** |
| Room background gradient | `mockups.css:18-21` | default window background | **absent** |
| Backdrop blur / veil | 5 uses | flat opacity fill | **absent** |
| `box-shadow` soft/float | 9 uses | none | **absent** |
| Noise / grain overlay | `mockups.css:92-101` | none | **absent** |
| Rule hairlines | 23 uses | `.quaternary` / `.secondary` | **absent** |
| Radius scale + organic blob radii | 6 steps + `54% 46% 42% 58%/…` | 3 literal values, plain circles | **absent as a system** |
| Spacing scale | 9 steps | inline literals 1–36 | **absent as a system** |
| Blob/panel/accent gradients | 9 named | field blobs only | approx |

Whole token families — veil, scrim, shadow, rule, danger, calm — have no representation at all.

**Open question, not scored as a gap:** `tokens.css` defines no dark variant, so the mock may be single-theme by intent. The app has no `colorScheme` handling whatsoever. If the mock is deliberately single-theme, that is parity, not a defect. This needs a product answer.

### 3.4 Screens

| Screen | Parity | Principal omissions |
|---|---|---|
| Initiate | partial | subtext; the entire companion-intro aside (field, companion copy, privacy note); policy-aware begin label and subtitle |
| Focus | partial | headline/subtext; focus-status badge; **rewind/forward ±1 min**; session-progress rail; on-surface check-in/break buttons; scratch timestamps and type tags |
| Check-in | partial | headline/subtext; **live response message never rendered** (D3); companion-log aside; explicit return-to-focus control |
| Break | partial (closest) | break countdown; intro question line; sitting-duration provenance factor |
| Review | partial→minimal | add-note; capacity bar chart; 4-stat metrics block; timeline kind tags and date subtitle |

Headline copy matches verbatim on initiate, break and review. Focus and check-in headlines are simply not rendered. Two of four check-in response strings diverge in wording from the approved mock.

The menu-bar popover, capsule and return overlay have **no mock counterpart** — the mock never depicts them. They were correctly scoped as M1 non-goals and designed fresh in M2.

### 3.5 Interactions

| Mock interaction | Status |
|---|---|
| Space toggles timer | implemented |
| Four check-in answers | implemented |
| **Rewind / forward ±1 min, `+`/`-` keys** | **absent, and unrecorded anywhere** |
| Hover / press / focus feedback | **absent** |
| Cross-screen quick capture | absent |
| In-app "Motion: still" toggle | **absent — but specified** (D1) |
| Global digit keys 1–5 for screen jump | absent (prototype scaffolding — reasonable to drop) |
| 320 ms settle beat before begin transitions | absent |
| Break choice confirmation message | absent — choice is persisted, feedback is not shown |
| Timestamped scratch entries | approx — plain strings |

---

## 4. Why the implementation is so far from the design

### 4.1 What the record actually says

There *is* a recorded deferral. It lives in two code comments:

- `CompanionFieldView.swift:3-5` — "exact color pipeline lands with the **design-system pass in group 6**"
- `SurfacePalette.swift:9-10` — the same deferral repeated for surface tokens

And one recorded design risk:

- `archive/2026-07-31-add-app-scaffold-core-loop/design.md:21,34` — "Metal shader ambition deferred until a measured need"

### 4.2 The pointer rotted

M1's actual group 6 (`archive/…/tasks.md:6.1-6.6`) is: capability registry, copy-tone lint, accessibility suite, network-silence harness, provenance, final gauntlet. **There is no colour or design-system task in it.** M2's groups 1–9 contain none either.

So the comment points at a phase that arrived twice and never contained the promised work. It survived two milestones and nine independent-validator passes without anyone flagging it stale — including me.

### 4.3 Visual fidelity was never a requirement

This is the crux. The only visual-adjacent EARS requirement is "Companion field physics" (`openspec/specs/focus-loop-ui/spec.md:28-37`), and every clause in it is **behavioural**: breath asymmetry, spring damping, non-repeating drift, one damped pulse. All golden-testable, all golden-tested.

It never mentions colour, gradient softness, blur radius, shadow, typeface, or the "warm dusk-light paper" language that `openspec/config.yaml:8` calls the approved direction.

`SPEC.md:9` says the mocks are a "binding reference" — but that is prose in a preamble, not a gate. M1's seven gates and M2's six gates contain **zero** visual-fidelity criteria. The only pixel-level tests in the repo measure *contrast ratios*, not palette fidelity.

### 4.4 Conclusion

**Mixed, weighted to a systemic cause. Confidence: high.**

- Not pure oversight: a deferral was known and written down.
- But the deferral was never elevated to a proposal non-goal, a design decision with a target, a `tasks.md` atom, or an EARS scenario — the four places this repo's own contract (`AGENTS.md`, `openspec/config.yaml:20-22`) requires decisions and follow-ups to live. A code comment is not a backlog.
- The interaction gaps — rewind/forward, hover, press feel, quick capture — were never even *named* as deferred. They appear in no spec, so test-first development had nothing to assert and therefore produced nothing.

The method that made the engine excellent is the same method that starved the surface. A red→green→validator loop builds exactly what can be expressed as a failing assertion. Physics constants, contrast ratios, event counts and state machines express beautifully. "Does this feel like the warm room in the mock?" does not — so it was never written, never failed, and never got built.

Five successive validators attacked the no-second-clock invariant with real exploits. **None** of them looked at colour, motion or feel, because no criterion pointed them there.

---

## 5. Recommended remedy

1. **Fix the three defects first** — they are spec violations, not polish. Add the in-app "Motion: still" control (D1), forward `pulseSignal` from all field-bearing surfaces and pulse on hold/begin (D2), and either render `lastCheckinResponse` or delete it (D3).
2. **Make fidelity testable before building it.** A design-system milestone that is only prose will fail the same way. Candidate assertable criteria: a `DesignTokens` Swift layer whose values are *derived* from `tokens.css` by a checked-in converter with a parity test; a snapshot-image test per surface against committed references; an assertion that no view uses a literal colour, spacing or radius outside the token layer.
3. **Decide the typeface question explicitly.** Bundle Gabarito/Hanken Grotesk/Sono as app resources, or record "system fonts" as an accepted amendment to the approved direction. Right now it is neither.
4. **Retire the stale pointer.** Replace both "group 6" comments with a real linked atom, or delete the claim.
5. **Answer the two open product questions:** is the mock single-theme by design, and is rewind/forward wanted at all (a canonical-timestamp engine makes manual time-travel genuinely awkward to keep honest — that may be a good reason to drop it, but it should be *recorded* as one).
