# Proposal: add-session-settings

## Why

Praxmodoro has no settings surface at all. The only preferences that exist are a menu-command motion toggle and four fixed timing policies chosen at initiation. For the product's actual audience this is not minimalism, it is a missing limb: sound is how time stays perceptible without looking (research w1-adhd-research on time-blindness scaffolding), and a rhythm that continues by itself is the difference between a tool that carries you and one you must carry. The owner's comparison against RoundPie (build 1641, 2026-08-12) made the gap explicit and directed its closure: "fix all, especially sounds and automatic break/focus."

This change gives the rhythm a body — durations you choose, breaks that can begin themselves gently, sound that marks transitions — behind a standard macOS Settings window, with every RoundPie-shaped feature bent to this product's invariants rather than copied.

## Goals, non-goals, assumptions

**Goals:** a Settings scene (⌘,) with Rhythm and Sound & Notifications panes; custom focus and break durations as data-driven policies; long-break cadence; a three-way autostart behaviour setting (owner decision 2026-08-12: offered-default / prompt-first / manual, shipping default **prompt-first**); the ±1-minute rewind/forward adjustment as an honest engine event (owner decision: keep); first sound in the app (ticks and chimes, all default off); local block-end/break-end notifications with editable text.

**Non-goals (this change):** the Appearance & Presence pane (lands with the token work — approach D join point); accounts, sync, analytics; global hotkeys; layout options; any setting that gates the never-paywalled set; font bundling (ticket #9, separate change).

**Assumptions:** the injected `UserDefaults` seam (proven by the Motion: still preference) carries all settings; `expiryInstant()` / `promotionInstant()` remain the scheduling anchors; AVFoundation and UserNotifications are available without new third-party dependencies.

**Edition impact:** everything ships in Lite. New capability keys join the registry; none are paywallable.

**User value:** durations that fit real attention instead of four presets; a block-end that continues into rest by itself — at the softness the user chose; time made audible for whoever wants it, silent for whoever doesn't; and a session that can be nudged a minute without lying to the engine.

**Measurable success:** every EARS scenario below covered by a passing automated test; `./scripts/verify-project.sh` exits 0; `npm run spec:validate` strict passes; the module-wide no-scheduling and clock-read guards stay green — autostart, sounds and notifications introduce zero UI-side timers.

## What Changes

- **New Settings scene** (standard macOS Settings window, ⌘,) with Rhythm and Sound & Notifications panes. Panes draw colour and spacing exclusively through `SurfacePalette` semantic roles.
- **Engine (PraxmodoroCore):** custom `TimingPolicy` construction from user values; long-break cadence as policy data; a recorded `adjustment` transition (±60s) for rewind/forward; an autostart transition at the canonical expiry instant, recorded exactly like the existing gentle-start promotion.
- **App:** `RhythmPreferences` and `SoundPreferences` on the injected defaults seam; the block-end flow honouring the three-way autostart setting; a `SoundPlayer` (AVFoundation) driven by engine transitions; local notifications (UserNotifications) with lint-clean shipped defaults and verbatim user text.
- **Registry:** `sessionSettings`, `rhythmControl`, `soundCues` capability keys, all Lite.

## Capabilities

### New Capabilities
- `session-settings`: the Settings scene, rhythm preferences, autostart behaviour, rewind/forward, sound cues, and local notifications — and the invariants that bend them.

### Modified Capabilities
- `timer-engine`: gains the adjustment transition and the autostart-at-expiry transition ("User-steerable timing policies" extended; "Flow never auto-ends" restated as binding on autostart).
