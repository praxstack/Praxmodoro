# add-session-settings fresh-validation remediation plan

Date: 2026-08-23
Change: `add-session-settings`
Owner decision: #18
Status: complete 2026-08-26; archived as `2026-08-26-add-session-settings`; post-archive signed gate passed 237/237

## Objective

Bring the active `add-session-settings` capability into agreement with its EARS requirements and the later owner sound decision, then produce current evidence strong enough to archive it. This plan does not call the change “M3”; `SPEC.md` reserves that milestone name for later staged integrations.

## Required repairs

| Area | Current defect | Accepted contract |
|---|---|---|
| presets | add/remove only; first break preset silently wins | edit/remove every row; all configured focus/break pairs selectable; persisted policy names keep history readable |
| settings tokens | panes do not call `SurfacePalette` | existing palette supplies colors/contrast; generated tokens supply explicit spacing/radius |
| settings accessibility | no actual-pane transparency/contrast or sample VoiceOver evidence | opaque/7:1 raster contracts plus five cue-specific keyboard/VoiceOver actions |
| notifications | denial callback races a previously scheduled request | callback marks unavailable and immediately cancels/resynchronizes |
| sounds | four cues, factory off, no samples | five cues; start + both chimes on at 0.7; ticks off; five samples; all optional |
| saved sound compatibility | synthesized decode will reject a valid pre-block-start blob | keyed decode preserves legacy values and defaults only the new cue off |
| live auto-return | phase-only observation can miss a full cycle; first post-relaunch render can catch up absence | observe every root date edge; Core admits only a break end later than this process's live boundary |
| audio retention | completed players can accumulate and future-player retention is implicit | retain future scheduled players; prune only completed players through a tested pure decision |
| wake-late chime | AVAudioPlayer device time can resume an expired scheduled cue | native wake event cancels every pending chime at or before wall-clock now before resync |
| evidence | tasks 9.2/9.3 and settings prd/progress evidence absent | fresh full gates, per-atom red→green receipts, independent COMPLETE verdict |

## Settings information architecture

```text
Settings
├── Rhythm
│   ├── block-end behavior + auto-return
│   ├── editable focus presets
│   ├── editable break presets
│   └── long-break cadence
└── Sound & Notifications
    ├── master volume
    ├── five rows: label + toggle + sample
    └── notification availability, toggles, and text
```

The repair adds no pane, card, modal, account, or network path. Preset editing stays inline in the existing list. Sound sampling is a trailing button on each existing cue row.

## Interaction-state table

| Feature | Empty | Success | Error/unavailable | Partial |
|---|---|---|---|---|
| preset list | “The built-in policies are always available.” plus Add | editable unique whole-minute rows (`1...240`) with Remove | invalid/fractional/range/duplicate input stays uncommitted beside persistent help | one family may be custom; the other uses classic fallback |
| sound sample | five rows always visible, cue-labeled for VoiceOver, and keyboard reachable | `AppModel.previewSound(_:)` schedules one cue at current volume; no preference mutation | missing/device failure stays silent | master volume applies immediately |
| notifications | toggles off by factory | canonical request shown by enabled toggle | denied message; controls disabled; pending request cancelled | availability check outstanding keeps current state until callback |

## Test-first implementation order

1. Freeze and strict-validate the amended OpenSpec artifacts.
2. Repair preset editing/pair reachability/history proof.
3. Wire settings palette and contrast tokens.
4. Close the denial callback race.
5. Land runtime task 3's canonical break-end/live-boundary API.
6. Add the fifth cue, owner-approved defaults, legacy keyed decode, transition-edge behavior, robust date-edge auto-return observation, resources, and keyboard-reachable sample actions.
7. Fix audio-player retention/pruning.
8. Run code review over the complete uncommitted diff; fix and re-run until clean.
9. Run fresh Core, Store, focused, signed full, smoke, copy-tone, generation-staleness, and strict spec gates.

## Failure map

| Path | Production failure | Test/error behavior |
|---|---|---|
| preset edit | stale index or invalid value corrupts future selection | reject rather than clamp: unique whole `1...240`, persistent help, historical store unchanged |
| custom pair | configured break never becomes selectable | exact policy-set test including break-only fallback |
| permission callback | denied request remains scheduled | deferred callback test requires cancel and no reschedule |
| start cue edge | duplicate on render/relaunch or absent on auto-return | recorder covers begin/end-break/auto-return/hold/relaunch |
| sleep-expired chime | device timebase resumes an old pending player | wake cancellation stops/removes expired stopped or playing entries before presentation resync |
| live observation | phase-only callback misses a complete cycle, or first render catches up an absent one | date-edge observer plus Core `autoReturnAfter` boundary covers sleep and relaunch |
| legacy sound blob | new field makes valid saved choices fall back to factory-on values | fixture without `blockStart` preserves all old fields and defaults only the new field off |
| sample | changes preference/session, ignores volume, or cannot receive keyboard focus | inert-model snapshot/recorder plus signed `hasKeyboardFocus` traversal of five identifiers |
| Settings accessibility | palette wiring exists but rendered pane/labels do not change | actual-pane transparency/contrast rasters plus exact VoiceOver labels in signed UI |
| player pruning | future chime deallocated or completed player retained | `shouldRetainChime`: `isPlaying || scheduledAt > now`; no timer |

## Scope boundaries

Not in scope: app-owned notification sounds, haptics, user-imported audio, global shortcuts, Appearance & Presence, new preset sync/storage, or a Settings redesign. Those remain separate tickets.

## Delivery gate

`add-session-settings` remains unarchivable until tasks 9.2, 9.3, and 10.1–10.10 are complete, the current full gate and smoke exit 0, `prd.json`/`progress.txt` distinguish immutable historical gaps from current evidence, and a fresh validator returns COMPLETE against the amended spec. The owner's active-goal pre-approval on 2026-08-23 accepts the historical grouped-commit deviation; no retroactive red result may be invented.
