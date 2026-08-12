# Tasks: add-session-settings

Every task is red-test-first: write the failing test, watch it fail for the right reason, make it pass, run the guard suite. Core tasks verify with `swift test --package-path app/Packages/PraxmodoroCore`; app tasks with `./scripts/focused.sh`. The module-wide no-scheduling and clock-read guards must be green after every task — they are the standing proof that nothing here grew a second clock.

## 1. Engine: custom policies and cadence (Core)

- [ ] 1.1 Test: a `TimingPolicy` constructed from user values (e.g. 40/8) derives remaining time identically to a built-in preset shape; reconstruction from persisted transitions matches on simulated relaunch. Implement custom-policy construction as pure data.
- [ ] 1.2 Test: long-break cadence (every N blocks, longer length) is policy data — the Nth block-end derives the longer break suggestion; no counter is persisted outside the transition history. Implement cadence derivation.
- [ ] 1.3 Test: removing a preset leaves prior session records readable and their derivations unchanged. Implement (likely a no-op proven by test — presets are construction-time data).

## 2. Engine: adjustment transitions (Core)

- [ ] 2.1 Test: appending an `adjustment(+60)` transition shifts `remaining(at:)` and `expiryInstant()` by exactly 60s; two `-60` adjustments reconstruct exactly after simulated relaunch. Implement the `adjustment` transition kind and fold it into derivation.
- [ ] 2.2 Test: adjustment then sleep through the shifted expiry — `reconciled(at:)` backdates the expiry using the adjusted derivation with zero drift. No new code expected; the test is the point.
- [ ] 2.3 Test: adjustments are rejected/ignored for non-running blocks (already-expired, held, closed) — history stays clean. Implement the guard in the transition validator.
- [ ] 2.4 Test: a persisted store containing adjustment records replays cleanly under the current schema; schema-parity test still passes untouched.

## 3. Engine: autostart at expiry (Core)

- [ ] 3.1 Test: with behaviour "offered default", `reconciled(at:)` past expiry records the break transition at the canonical expiry instant — including when the reconcile happens minutes later (sleep/quit case). Implement autostart in the promotion machinery.
- [ ] 3.2 Test: with behaviour "prompt first", expiry records the expiry-hold (place kept) and no break transition until an explicit accept, which records at accept time. Implement.
- [ ] 3.3 Test: with behaviour "manual", behaviour is bit-identical to today (golden derivation comparison). Implement (should be a no-op proven by test).
- [ ] 3.4 Test: flow policy + autostart "offered default" → zero automatic transitions at any probed instant. The "Flow never auto-ends" guard extended to the autostart path.
- [ ] 3.5 Test: behaviour setting is read at expiry-processing time — changing it mid-block governs the current block's end (design decision 4).
- [ ] 3.6 Test: auto-return enabled — break-end recorded at the canonical break-end instant (break start + chosen length), including across simulated sleep; disabled (factory default) — breaks stay open-ended. Implement auto-return in the same reconciliation pass.

## 4. Preferences on the defaults seam (App)

- [ ] 4.1 Test: `RhythmPreferences` (durations, cadence, autostart behaviour) round-trips through an injected ephemeral `UserDefaults`; factory default is prompt-first with today's durations. Implement the value type on the seam, mirroring the Motion pattern.
- [ ] 4.2 Test: `SoundPreferences` (master volume, per-cue toggles, tick loop) round-trips; factory default is everything OFF. Implement.
- [ ] 4.3 Test: malformed/missing defaults decode to factory values, never crash, never write back garbage.

## 5. Settings scene (App)

- [ ] 5.1 Test: the Settings scene exists with Rhythm and Sound & Notifications panes and opens via ⌘, without disturbing a running session (state-level assertion, not UI automation). Implement the `Settings` scene.
- [ ] 5.2 Test: Rhythm pane binds every `RhythmPreferences` field; changes land on the seam. Implement the pane — `SurfacePalette` roles only, zero raw literals.
- [ ] 5.3 Test: the flow-exemption notice is present in the pane's rendered content when flow policy exists. Implement.
- [ ] 5.4 Test: Sound & Notifications pane binds every `SoundPreferences` field plus notification toggles/texts. Implement the pane.
- [ ] 5.5 Test: store schema before/after the whole change is identical (existing schema-parity test re-run and cited in the task commit).

## 6. Block-end flow honours the setting (App)

- [ ] 6.1 Test: offered-default — at expiry the break surface appears with decline/end as one ordinary action; the transition instant equals the canonical expiry instant. Wire AppModel to pass behaviour into the engine.
- [ ] 6.2 Test: prompt-first — a non-modal offer renders; accept records the break; dismiss keeps the held place; copy passes the tone lint. Implement the offer surface on pure `CompanionDisplay` data.
- [ ] 6.3 Test: rewind/forward — `+`/`-` during a running block appends adjustments via `CompanionActions`; controls absent when not running. Implement controls and key handling.

## 7. Sound (App)

- [ ] 7.1 Commit bundled CC0/original sound assets under `app/Resources/Sounds/` with provenance in the commit message.
- [ ] 7.2 Test: `SoundPlayer` with everything OFF produces zero play requests across a full simulated session (seam: a played-cue recorder injected in place of AVFoundation). Implement `SoundPlayer` as a transition listener behind a protocol.
- [ ] 7.3 Test: chime enabled — exactly one chime per expiry, none retro-fired after a simulated sleep-through-expiry wake. Implement.
- [ ] 7.4 Test: tick loop starts with a running block and stops within one period of hold/close; implemented as an AVAudioPlayer loop toggle, no `Timer` — guard suite proves it. Implement.
- [ ] 7.5 Test: resource-load failure and device-vanish paths leave the session untouched and log quietly. Implement.

## 8. Notifications (App)

- [ ] 8.1 Test: notification requests are created from `expiryInstant()` on begin/adjust and cancelled on hold/adjust/setting-change (seam: injected notification-center protocol). Implement scheduling.
- [ ] 8.2 Test: shipped default texts pass the copy-tone lint; the lint explicitly exempts the user-text defaults keys. Implement defaults and lint carve-out.
- [ ] 8.3 Test: user-edited text is stored and passed to the request verbatim. Implement.
- [ ] 8.4 Test: denied permission renders toggles unavailable and schedules nothing; no re-prompt path exists. Implement.

## 9. Registry and gates

- [ ] 9.1 Test: `sessionSettings`, `rhythmControl`, `soundCues` resolve available in Lite; a hostile registry marking them non-Lite fails debug validation. Implement the keys.
- [ ] 9.2 Full gate: `./scripts/verify-project.sh` exit 0; `npm run spec:validate` strict; guard suite green; then single-line commit per task discipline and auto-push (standing green policy).
- [ ] 9.3 Independent fresh-context validator reviews the change against the spec deltas before archive; findings fixed before `openspec archive`.
