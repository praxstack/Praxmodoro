# Proposal: add-session-settings

## Why

Praxmodoro has no settings surface at all. The only preferences that exist are a menu-command motion toggle and four fixed timing policies chosen at initiation. For the product's actual audience this is not minimalism, it is a missing limb: sound is how time stays perceptible without looking (research w1-adhd-research on time-blindness scaffolding), and a rhythm that continues by itself is the difference between a tool that carries you and one you must carry. The owner's comparison against RoundPie (build 1641, 2026-08-12) made the gap explicit and directed its closure: "fix all, especially sounds and automatic break/focus."

This change gives the rhythm a body — durations you choose, breaks that can begin themselves gently, sound that marks transitions — behind a standard macOS Settings window, with every RoundPie-shaped feature bent to this product's invariants rather than copied.

## Goals, non-goals, assumptions

**Goals:** a Settings scene (⌘,) with Rhythm and Sound & Notifications panes; create, edit, remove, and select custom focus/break duration pairs as data-driven policies; long-break cadence; a three-way autostart behaviour setting (owner decision 2026-08-12: offered-default / prompt-first / manual, shipping default **prompt-first**); an off-by-default auto-return that records only a break end witnessed by the live process, including across sleep but never across relaunch absence; the ±1-minute rewind/forward adjustment as an honest engine event (owner decision: keep); five optional sounds with the owner-approved factory-on set of block-start, focus-end, and break-end while both ticks remain off (decision extended 2026-08-23 in #18); local block-end/break-end notifications with editable text.

**Non-goals (this change):** the Appearance & Presence pane (lands with the token work — approach D join point); accounts, sync, analytics; global hotkeys; layout options; any setting that gates the never-paywalled set; font bundling (ticket #9, separate change).

**Assumptions:** the injected `UserDefaults` seam (proven by the Motion: still preference) carries all settings; `expiryInstant()` / `promotionInstant()` remain scheduling anchors; runtime task #52 supplies the canonical `breakEndInstant(cadence:)` and process-live boundary used by auto-return, sound, and notifications; AVFoundation and UserNotifications are available without new third-party dependencies.

**Product availability:** everything ships in the one product. New capability keys join the internal provenance registry and cannot withhold behavior.

**User value:** durations that fit real attention instead of four presets; a block-end that continues into rest by itself — at the softness the user chose; moderate transition cues that make the factory experience perceptible without enabling continuous ticking, with every cue still individually optional; and a session that can be nudged a minute without lying to the engine.

**Measurable success:** every EARS scenario below covered by a passing automated test, including a complete focus→break→focus jump across sleep and a post-relaunch break that never catches up; `./scripts/verify-project.sh` exits 0; `npm run spec:validate` strict passes; the module-wide no-scheduling and clock-read guards stay green — autostart, auto-return, sounds and notifications introduce zero UI-side timers.

## What Changes

- **New Settings scene** (standard macOS Settings window, ⌘,) with Rhythm and Sound & Notifications panes. Panes draw color through `SurfacePalette` semantic roles and any explicit spacing/radius through generated `DesignTokens`; actual-pane rasters prove Reduce Transparency and Increase Contrast, and sample actions carry keyboard focus plus cue-specific VoiceOver labels. Domain values and fixed Settings window dimensions are not style tokens.
- **Engine (PraxmodoroCore):** custom `TimingPolicy` construction from user values; long-break cadence as policy data; a recorded `adjustment` transition (±60s) for rewind/forward; an autostart transition at the canonical expiry instant; and an auto-return transition at Core's canonical break end only when it is later than the current process's live-observation boundary.
- **App:** `RhythmPreferences` and `SoundPreferences` on the injected defaults seam; the block-end flow honouring the three-way autostart setting; a five-cue sound director (AVFoundation) driven by engine transitions, with sample actions through the existing scheduling seam and native wake cancellation preventing stale chimes; local notifications (UserNotifications) with lint-clean shipped defaults, verbatim user text, and denial callbacks that immediately cancel/resynchronize pending requests.
- **Registry:** `sessionSettings`, `rhythmControl`, `soundCues` capability-provenance keys, all always available.

## Capabilities

### New Capabilities
- `session-settings`: the Settings scene, rhythm preferences, autostart behaviour, rewind/forward, sound cues, and local notifications — and the invariants that bend them.

### Modified Capabilities
- `timer-engine`: gains adjustment, autostart-at-expiry, and witnessed auto-return transitions ("User-steerable timing policies" extended; "Flow never auto-ends" restated as binding on every automatic transition).
