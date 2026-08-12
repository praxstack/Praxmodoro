# Plan: settings & rhythm parity — proposed change `add-session-settings`

Date 2026-08-12 · Status: APPROVED (CEO review, approach D) · Trigger: RoundPie comparison (owner screenshots, build 1641) — "I think we have no settings or very few. Fix all, especially sounds and automatic break/focus."

## The gap, measured

Praxmodoro today has **zero** settings surface. The only user preferences that exist are the in-app "Motion: still" toggle (a menu command) and the four fixed timing policies chosen at initiation. RoundPie ships ~25 settings. The honest comparison, filtered through our own product boundaries:

| RoundPie setting | Ours today | Verdict for us |
|---|---|---|
| Autostart timers (25/35/40/45/50 presets) | 4 fixed policies, no custom durations | **Adopt, adapted** — custom focus durations as data-driven policies |
| Autostart breaks (5/10/15) | breaks are fully manual | **Adopt, adapted** — offer, never force (see invariant note) |
| Long breaks (every N timers, length) | nothing | **Adopt** — cadence-aware suggestion |
| Notifications on/off + custom stop text | none (M2 non-goal) | **Adopt** — local UNUserNotification, optional, gentle copy |
| Bring app to front | none | **Adopt** as part of notification action |
| Sounds: volume, timer tick, tick loop, break tick, timer alarm, break alarm | **zero sound in the app** | **Adopt** — the owner's top ask |
| Tray: task name (+max length), remaining time, break time, seconds | icon-only MenuBarExtra | **Adopt** — live menu-bar label is high value |
| Show icon in Dock | always shown | **Adopt** — activation-policy toggle |
| Always on top | capsule only | **Adopt** — extend to main window |
| Dark theme toggle | no dark mode at all | **Adopt** — answers the open single-theme question: NOT single-theme |
| Layout list/tiles, visible items | n/a (no task list) | **Skip** — not our shape |
| Connected services / sync / account | none | **Skip** — local-first invariant, M4+ territory |

## Where our invariants bend RoundPie's shape

These are not softenings — they are the product's identity, and each is already an EARS-tested rule:

1. **"No punitive mechanics (forced breaks)"** — `SPEC.md` global invariant. So *autostart break* here means: when a block's focus ends, the break **begins as the offered default** with a visible, ordinary way to decline or end instantly ("Ending early is ordinary" is already spec). Never a lockout, never a modal wall.
2. **"Flow never auto-ends"** — timer-engine spec. Autostart cannot apply to the flow policy; the settings UI must say so rather than silently ignore it.
3. **Sound is never a nag.** Ticks and alarms exist for people whose time-blindness sound genuinely helps; defaults are OFF, per-sound toggles, and the copy-tone lint applies to notification text (no urgency language). Custom notification text passes through the same lint at save time? No — lint is a build-time test; runtime custom text is the user's own words, not product copy. Product-provided defaults are linted.
4. **Every new capability joins the Lite grant.** Settings are not a Pro hook. `CapabilityRegistry` gains keys; none join the paywallable set.
5. **Canonical timestamps stay the only clock.** Autostart transitions are engine events recorded at their canonical instant (the block's expiry), exactly like the existing gentle-start promotion — not timers firing in the UI. Sound/notification scheduling derives from `expiryInstant()`; a fired notification is presentation, never state.

## Proposed scope — OpenSpec change `add-session-settings` (M3 candidate)

**New capability `session-settings`:**
1. **Settings scene** (⌘,), standard macOS Settings window, three panes: Rhythm, Sound & Notifications, Appearance & Presence. All values in `UserDefaults` via the existing injected-defaults seam; schema untouched (settings are device preferences, not session data).
2. **Rhythm**: custom focus durations (add/remove presets, RoundPie-style), break durations, long-break cadence (every N blocks, length), autostart-break toggle, auto-return toggle (break end → focus offered), with the flow-policy exemption stated in the UI.
3. **Sound & Notifications**: master volume, per-sound toggles (focus tick, break tick, focus-end chime, break-end chime), tick-loop toggle; block-end/break-end local notifications with editable text (linted defaults), bring-to-front action toggle. Bundled sounds: 2–3 gentle samples, no third-party audio deps (AVFoundation).
4. **Appearance & Presence**: dark/light/system appearance (requires the dark Living Companion variant — feeds #8 token work, which is exactly why this lands after tokens), menu-bar label content (icon only / +time / +task with max length / seconds), Dock icon toggle, always-on-top for the main window, Motion: still (moves into Settings alongside its menu command).

**Explicit non-goals:** accounts, sync, layout/grid options, any setting that gates the never-paywalled set, global hotkeys (still deferred).

**Sequencing — approach D, approved 2026-08-12: two parallel lanes.**
UI and gap-fixes are BOTH priorities; the only true dependency is that the Appearance pane needs tokens to exist.

- **Lane 1 (starts now):** engine extensions (custom focus/break durations as `TimingPolicy` values, long-break cadence, autostart transitions as canonical engine events anchored on `expiryInstant()`), then the Rhythm and Sound & Notifications panes. Discipline rule: panes draw colour/spacing ONLY through `SurfacePalette` semantic roles — never raw values — so they re-theme automatically when tokens land beneath it.
- **Lane 2 (starts now, in parallel):** issue #8 — the `DesignTokens` converter from `tokens.css` with a parity test, PLUS the dark Living Companion variant. `SurfacePalette` becomes token-backed.
- **Joins:** Appearance pane (dark/light/system, menu-bar label, Dock icon, always-on-top) lands when lane 2 completes. #14's literal-ban lands last, as before.

**New GitHub tickets (draft):** #15 settings scene + Rhythm pane + engine policy extensions · #16 Sound & Notifications · #17 Appearance & Presence (blocked by #8) · #18 dark Living Companion token variant (folds into or blocks #8's converter).

## Risks / open questions for review

- **Autostart vs. "no forced breaks"** — the adapted semantics above; is "break begins as offered default, decline is one keystroke" the right reading, or should autostart merely *prompt*?
- **Custom notification text** — user-authored text is exempt from tone lint by principle (their words); defaults linted. Agree?
- **Dock-icon toggle** requires `NSApp.setActivationPolicy` juggling with the Settings window open — known macOS awkwardness, needs a design.md decision.
- **Rewind/forward (#6)** — still undecided; the Rhythm pane is its natural home if kept. This plan neither includes nor excludes it.

## GSTACK REVIEW REPORT

Mode: SCOPE EXPANSION ("bil the lake") · Reviewer: plan-ceo-review · Date 2026-08-12

| Run | Status | Findings |
|---|---|---|
| System audit | done | UserDefaults seam proven (Motion: still); TimingPolicy already data; expiryInstant/promotionInstant are the autostart anchors; zero audio/notification code exists |
| Premise (0A) | pass | Right problem, reframed: not 25 toggles — "give the rhythm a body" (perceptible time without looking). RoundPie list = checklist, not goal |
| Leverage (0B) | pass | Nothing rebuilt; every pillar reuses an existing, tested seam |
| Alternatives (0C-bis) | decided | A panes-first / B tokens-first / C mirror-sprint presented; user rejected the A-vs-B dilemma as false; **D both-lanes-parallel** approved (the only hard dependency is Appearance→tokens) |
| Failure modes | recorded | UI-side timers structurally banned (guard-enforced); autostart must be engine events; "no forced breaks" invariant bends autostart to offered-default; flow policy exempt and UI must say so |
| Expansion ceremony | compressed | Owner pre-directed scope ("fix all… add new features too") via screenshots; adopt-list in the Proposed-scope section IS the accepted expansion set. Additional delight ideas deferred to ticket bodies rather than more dialogs — owner signalled dialog fatigue |

VERDICT: APPROVED — approach D, scope = the Adopt table + three-pane settings surface, invariants intact (no forced breaks, flow never auto-ends, engine is the only clock, everything Lite).

NO UNRESOLVED DECISIONS
