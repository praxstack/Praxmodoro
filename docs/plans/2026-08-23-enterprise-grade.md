# Enterprise-grade pass — CEO review (plan)

Generated 2026-08-23 by /plan-ceo-review (+ office-hours builder lens, grilling/domain-modeling discipline).
Mode: **SELECTIVE EXPANSION** — hold the ticketed roadmap (#7, #17–#34), cherry-pick hardening and truth-telling work from two parallel code audits.
Authority: Prax granted autonomous subagent fan-out and decision authority for this review; every gate below records its ruling and remains vetoable.

## Premise challenge

- **Is "enterprise-grade" the right problem?** Rephrased: the app must earn daily-driver *trust*. Features are already charted (24 open tickets). What is missing is the guarantee that the app never loses a byte, never shows a lie, and never fails silently. That is the actual ask, and it is the right one: session history is the product's memory, and today three defects put that memory at risk.
- **What if we do nothing?** The store-open failure path silently disables all persistence while looking normal; 26 `try?` sites can diverge on-screen state from the persisted record; the first schema change quarantines the entire history without telling anyone. These are not hypotheticals — they are written in the code today.
- **Framing ruled out:** adding an Enterprise tier (contradicts issue #34, owner-authorized), and adding net-new feature surface beyond the ticketed roadmap (premature — the roadmap is already the feature work).

## Existing-code leverage (audit finding, high value)

Four capabilities are fully built and idle; wiring them is cheaper than building anything:

| Dead capability | Where | Unlocks |
|---|---|---|
| `checkinBecameDue()` scheduling path | AppModel.swift:462–486 | Coach-initiated check-ins |
| `.edit` event API (`editEvent`) | LocalStore.swift:179–181 | Real "make the step smaller" |
| `clockAnomaly` event kind | LocalStore.swift:12 | Honest-time guarantee |
| `focusElapsed(at:)` | SessionTimeline.swift:9–16 | Elapsed time for flow blocks |

## Approaches considered

```
APPROACH A: Hardening minimum
  Summary: fix the three data-loss risks + the parked-thoughts defect only.
  Effort: S · Risk: Low
  Pros: smallest diff; kills every data-loss path.
  Cons: leaves the lying surfaces (00:00 breaks, fake "smaller step") that erode trust daily.
APPROACH B: Trust pass (RECOMMENDED)
  Summary: data-safety triad + wire all four dead capabilities + surface-truth fixes +
  diagnostics + distribution base. Two OpenSpec changes, ~17 atoms.
  Effort: M/L · Risk: Low-Med
  Pros: the app stops being able to lie; coach participates; years-of-use durability.
  Cons: bigger than A; distribution item needs an owner decision (Apple Developer account).
APPROACH C: B + all product refinements
  Summary: everything from both audits including presets management, nudge granularity,
  capacity restatement, reflection notes.
  Effort: L · Risk: Med (collides with unlanded tickets #20–#22, #30)
  Pros: maximal. Cons: churn against moving surfaces; defers poorly.
```

**Ruling: Approach B**, SELECTIVE EXPANSION. A is under-scoped for a trust goal; C drags unlanded feature surfaces into a hardening pass.

## Accepted scope (filed as tickets, ready-for-agent)

**Change lane 1 — data trust (`harden-data-trust`):**
1. Surface persistence-failure states (nil-store alert, recovery notice shown, orphan-session prune)
2. Persist-before-mutate; stop swallowing store errors; one observable error channel
3. VersionedSchema v1 + migration plan before any model change
4. Wire `clockAnomaly` on wake/jump; clamp negative remaining
5. Local diagnostics: OSLog categories + last-session breadcrumb
6. Store index + O(1) orderIndex derivation
7. Parked-thoughts bleed defect (clear on begin)
8. Backup escape hatch — amendment to #25 (reveal store in Finder; auto-copy on version mismatch)

**Change lane 2 — companion presence grade (`companion-presence-grade`):**
9. Coach-initiated check-ins (gentle cadence, off by default)
10. Break countdown on popover/capsule (no more 00:00 during breaks)
11. "Smaller step" really edits the step (via `.edit`)
12. Flow blocks show counting-up elapsed
13. Capsule phase-aware controls (parity with popover)
14. Name the drift: optional detour note on check-in
15. Review shows durations + honest session totals
16. Capsule joins all Spaces / fullscreen auxiliary

**Operational (owner decision embedded):**
17. Developer ID signing, notarization, minimal update story

## Deferred to future (not forgotten)

Capacity restatement at breaks (design-sensitive, touches check-in cadence) · named custom presets with arrival ramps · ±5-minute nudges and adjustments while held · one-line session reflection at close-out (let #22 land first) · multi-display pinning.

## Verified non-problems (checked, not assumed)

Quit-during-session and sleep/wake replay are correct by construction (canonical timestamps, pinned tests). Corruption recovery mechanics preserve the old file and start fresh (tested). Append-only discipline holds. Time Machine covers the store location by default.
