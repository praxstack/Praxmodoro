# M2 fresh-validation remediation plan

Date: 2026-08-23
Change: `add-companion-surfaces`
Umbrella issue: #7
Status: complete 2026-08-26; archived as `2026-08-26-add-companion-surfaces`; post-archive signed gate passed 237/237

## Objective

Close the four behavior/accessibility defects and one evidence gap found by the 2026-08-23 independent validator, and apply the already authorized one-product contract in issue #34, without redesigning the companion surfaces.

## Frozen findings

| Requirement | Verified defect | Minimal repair |
|---|---|---|
| One product | Edition API and About/docs tier copy survive issue #34 | one configured feature-key set; all keys available; version/SHA provenance only |
| Companion surfaces are never paywalled | scenes never consult `CapabilityRegistry` | direct scene-level guard for each existing key, pinned to its construction site |
| Accessibility alternates on every companion surface | capsule and return overlay omit Increase Contrast | actual popover/capsule/overlay raster tests plus existing palette wiring |
| One canonical session state | focus task/state uses `Date()`, readout uses nested `context.date`, and overlay uses a second `Date()` | capture one main root-context `SessionSnapshot` for route/focus/overlay; the existing phase callback reads the local without changing behavior |
| Return overlay remains until acknowledgement | `openCheckin()` clears `returnPending` | reuse `checkinPending`; hold once, keep overlay visible, route after acknowledgement |
| Full keyboard loop | signed UI evidence omits hold/resume, break choice, thought parking, and visible focus | extend the existing hermetic XCUITest using native focus traversal and existing shortcuts |

## Interaction decisions

- A check-in requested under a pending return overlay holds the session once and waits in `checkinPending`; the stored route remains focus so the overlay stays visible. Acknowledgement clears the overlay and opens that waiting check-in without itself changing the held phase.
- Capability consultation cannot withhold these surfaces: the one-product registry resolves every defined key available, so consultation is an executable provenance boundary, not an unavailable state.
- The settings and visual language do not change. Contrast uses existing tokens; no mockup or new component is required.

## Implementation order

1. Add each failing test and capture the expected failure.
2. Remove edition framing while preserving the registry/provenance harness.
3. Fix registry consultation and contrast wiring.
4. Move the whole focus render under one snapshot instant.
5. Restore the overlay acknowledgement invariant.
6. Extend real keyboard-event evidence.
7. Run focused checks after each atom; keep the full diff uncommitted until code review is clean.

## Failure and test map

| Path | Failure if wrong | Proof |
|---|---|---|
| one-product registry/About | a key can be withheld or user copy exposes a tier | all-key/hostile-fixture runtime test plus version/SHA-only About test |
| capability scene gate | a companion surface bypasses provenance | exact per-key computed guard enclosing its scene/overlay, compiled one-product presence, hostile-omission test |
| contrast environment | system Increase Contrast has no effect | fixed-backdrop raster of the actual popover, capsule, and overlay plus pixel-mask/token matching |
| main-window render | route, focus values, existing presentation callback input, and overlay can cross instant boundaries | one root snapshot local, unchanged phase callback reads that local, sentinel injection, and zero `FocusSurface`/overlay clock reads; settings 10.7 owns later date-edge materialization |
| overlay/check-in | re-entry card disappears or check-in is lost | AppModel regression through end break → request/hold → acknowledge/route |
| keyboard traversal | a control exists but cannot be reached or focused | signed XCUITest identifier plus `hasKeyboardFocus` assertions before key activation |

## Scope boundaries

Not in scope: new shortcuts, companion-field fidelity (#10), token migration (#12), global hotkeys (#19), or new overlay persistence. Add one only if a red acceptance test proves the existing native path cannot satisfy the active M2 requirement.

## Delivery gate

M2 remains unarchivable until every remediation task is complete, the full gate and smoke pass from a fresh shell, `prd.json`/`progress.txt` carry current red→green evidence, and a fresh validator returns COMPLETE.
