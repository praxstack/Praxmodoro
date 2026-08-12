# Design: add-session-settings

## Context

The plan of record is `docs/plans/2026-08-12-settings-parity.md` (approach D, lane 1), with every open product question resolved by the applied dcanvas export `01KZTPM2DDFA8Q5ZM76ES0JXEJ`: autostart is a three-way user setting defaulting to prompt-first; rewind/forward is kept as an engine event; user notification text is verbatim; typography is a separate ticket. The engine's law — remaining time is `f(transitions, now)` — has survived six adversarial attempts against its guards this month; nothing in this change may weaken it.

Within the goal-ledger convention this file is the architecture record; `proposal.md` is the HLD and `tasks.md` the LLD.

## Goals / Non-Goals

**Goals:** every new time-shaped behaviour is an engine transition; every preference lives on the injected defaults seam; sound and notifications are pure presentation; the panes are token-ready without waiting for tokens.

**Non-Goals:** the Appearance pane (joins after lane 2), font bundling (#9), any new persistence schema, any UI-side scheduling.

## Decisions

1. **Adjustments are transitions, not offsets.** Rewind/forward appends an `adjustment(seconds:)` transition record; `remaining(at:)` folds adjustments into the derivation. *Alternative — a mutable `bonusSeconds` on the session:* rejected; mutable state beside an event-sourced timeline is exactly how drift enters, and it would not survive the relaunch-reconstruction property.
2. **Autostart reuses the promotion machinery.** `reconciled(at:)` already inserts the gentle-start promotion at its canonical instant; the autostart break transition is the same shape gated on the behaviour setting, and the auto-return-to-focus transition (break end → focus offered, plan §Rhythm) is the same pass anchored on the break-end instant, off by default. Sleep/wake correctness is inherited rather than re-proven. *Alternative — an app-layer observer firing on expiry:* rejected; it is a UI-side clock and the guards ban it structurally.
3. **Prompt-first is presentation over a held engine.** In prompt-first mode the engine records expiry-hold (block complete, place kept) and the app shows a non-modal offer; accepting records the break transition at accept time, with provenance noting the offer. The engine never encodes "a prompt is showing" — that is surface state, like the return overlay.
4. **Behaviour setting read at expiry-processing time, not captured at begin.** Changing the setting mid-block affects the current block's end; least-surprise wins over snapshot semantics. Recorded here because it is the kind of ambiguity implementers otherwise decide silently.
5. **Sound is a transition listener.** `SoundPlayer` (AVFoundation) observes the same state changes surfaces render; ticking is an `AVAudioPlayer` loop started/stopped by state, never a `Timer`. The chime for an expiry that happened while asleep does not retro-fire — a sound after the fact is noise, not information. *Alternative — scheduling sounds ahead via `AVAudioEngine` at absolute times:* deferred; complexity unjustified until someone asks for sub-second precision.
6. **Notifications are scheduled at canonical instants and cancelled on change.** `UNUserNotificationCenter` requests are created from `expiryInstant()` when a block begins or is adjusted, and cancelled/recreated on hold, adjustment, or setting change. The notification fires even if the app is quit — which is the point. Denied permission renders the toggles plainly unavailable; no re-prompt nagging.
7. **Preferences are two small value types** (`RhythmPreferences`, `SoundPreferences`) decoded from the injected `UserDefaults`, mirroring the Motion: still pattern; no new storage, no schema change, schema-parity tests untouched.
8. **Panes speak `SurfacePalette` only.** The token layer will re-back `SurfacePalette` (lane 2); these panes therefore contain zero raw colour/spacing literals, verified by the same review discipline that will become #14's enforced ban.

## Data boundaries

No new persisted models. Session records gain nothing; adjustment and autostart transitions reuse the existing transition event vocabulary (`adjustment` joins `SessionIntent`/record kinds in Core only). Preferences live in defaults; notification text lives in defaults; sounds are bundled resources.

## Dependency provenance

AVFoundation and UserNotifications are platform frameworks. No third-party packages. Sound assets are original or CC0, committed under `app/Resources/Sounds/` with provenance noted in the commit.

## Rollback

Additive scenes and Core extensions. Removing the Settings scene and the two new transition kinds restores current behaviour; sessions recorded with adjustments remain readable because unknown-intent records already tolerate replay (verified in tasks).

## Verification strategy

Per-atom red→green via `./scripts/focused.sh`; Core work via `swift test --package-path app/Packages/PraxmodoroCore`. The no-scheduling and clock-read guards must stay green throughout — they are the proof that autostart and sound introduced no second clock. Full gate `./scripts/verify-project.sh` plus `npm run spec:validate` strict at change completion, then the independent fresh-context validator before archive.
