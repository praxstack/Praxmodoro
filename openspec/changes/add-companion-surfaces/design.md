# Design: add-companion-surfaces

## Context

M1 shipped one window containing five surfaces, a deterministic engine (`PraxmodoroCore`), a local append-only store (`PraxmodoroStore`), and a golden-tested physics port (`FieldPhysics`). The engine rule that matters most here is already established and must not be weakened: remaining time is `f(transitions, now)` and ticks are presentation only. Adding surfaces is therefore mostly a *state-authority* problem, not a rendering problem — three more views that each need to show the time are three more chances to accidentally introduce a second clock.

Inputs are binding: `AGENTS.md` (spec-first, TDD, deterministic timing, local-first, never-paywalled set), `SPEC.md` global invariants, the approved Living Companion mocks, and the four hardening follow-ups recorded in the M1 closeout entry of `progress.txt`.

This document is the change's architecture record. Within the goal ledger tracking this milestone it is registered as the **architecture** artifact; `proposal.md` is the **high-level design** (scope, goals, non-goals, edition impact, measurable success) and `tasks.md` is the **low-level design** (exact files, exact failing test, exact green criterion, per atom). No parallel design tree is created — these three artifacts already carry that content and are the ones the repository's own workflow reads.

## Goals / Non-Goals

**Goals:** make a second clock structurally impossible; keep every new surface a pure projection; close the four hardening follow-ups with tests that could actually fail; keep the store schema and the event vocabulary untouched.

**Non-Goals:** global hotkeys, notifications, entitlements, agent-only (Dock-less) mode, AppKit window subclassing, sync, integrations, Pro/Enterprise content.

## Decisions

1. **One `SessionSnapshot` value, one accessor, every surface reads it.** `AppModel.snapshot(at: Date) -> SessionSnapshot` projects the engine into everything a surface can legitimately render: phase, task line, next action, remaining interval, remaining *text*, status line, VoiceOver summary. The text formatting lives in the snapshot, not in each view, so "the three surfaces agree" is a property of one function rather than a coincidence of three copies. `FocusSurface` is migrated onto it in the same atom that introduces it, so there is never a moment where two formatting paths exist.
   *Alternatives:* let each surface call `model.remaining(at:)` and format locally — rejected: it is exactly the duplication the criterion forbids, and it makes the agreement test a tautology over three separate implementations. A `@Published` snapshot recomputed on a timer — rejected: that *is* a second clock, and it would drift across sleep.

2. **`MenuBarExtra` + a `Window` scene with `windowLevel(.floating)`, not AppKit.** Both surfaces are SwiftUI scenes in the existing `App` body. The capsule uses `.windowLevel(.floating)`, `.windowStyle(.hiddenTitleBar)`, `.windowResizability(.contentSize)` and `.defaultLaunchBehavior(.suppressed)` so it never opens itself. Opening and closing go through `@Environment(\.openWindow)` / `dismissWindow` driven by a `CommandGroup` entry, which is what gives the capsule its keyboard path.
   *Alternatives:* an `NSPanel` with `.floating` level via `NSViewRepresentable` — rejected: it reintroduces AppKit window lifecycle the SwiftUI scene graph already owns, and it is harder to drive from a UI test. `NSStatusItem` built by hand instead of `MenuBarExtra` — rejected: `MenuBarExtra` with `.menuBarExtraStyle(.window)` gives the same popover with scene-managed lifetime and no manual retain of the status item. The trade-off accepted here is that `MenuBarExtra` content is awkward to drive from XCUITest; that is why the popover's guarantees are pinned by unit tests over the view's control catalog and snapshot, and the capsule — which *is* a real window — carries the interface-level test.

3. **The return overlay is presentation state, not session state.** `AppModel.returnPending` is an in-memory flag set by `endBreak()` and cleared by `acknowledgeReturn()`. It deliberately does not persist and does not append an event: the acknowledgement is not something that happened to the session, and inventing a `SessionEvent` kind for it would change the store schema for a UI beat. Consequence, accepted: relaunching mid-break and then ending the break still raises the overlay (correct), but relaunching *while the overlay is up* returns straight to focus (acceptable — the next action is still on the focus surface).
   *Alternative:* persist an `overlayAcknowledged` event — rejected on schema-stability grounds above.

4. **A user-initiated check-in (⌘K) is added rather than faking a due timer.** The keyboard scenario requires driving check-in answers as real key events, and M1 only reached the check-in surface when one became due. Rather than expose a test-only hook, the loop gains the affordance a user would want anyway: check in now. It routes through the existing `openCheckin()`, so the timer-held invariant and the deferral behavior are unchanged.
   *Alternative:* a launch argument that forces a due check-in — rejected: a test-only path proves the test harness works, not the product.

5. **Accessibility alternates are proven by rasterization, not by reading source.** A `SurfacePalette` owns the two branches (`background(reduceTransparency:)`, `primaryText(increasedContrast:)`) and the new surfaces use nothing else for their background and primary text. Tests use `ImageRenderer` to rasterize a probe built from those same tokens over a known backdrop and sample pixels: opacity is asserted by the backdrop being absent, contrast by computing the WCAG ratio from rendered luminances. The M1 source-scanning tests stay — they catch a *new* surface that bypasses the palette, which pixel probes cannot see.
   *Alternative:* full-surface snapshot images compared against committed reference PNGs — rejected: brittle against font and OS rendering changes, and it answers "did anything change" rather than "is it opaque / is it legible".

6. **Schema parity is measured between two live `ModelContainer`s.** `LocalStore` exposes `containerSchema`; the test opens one in-memory store and one on-disk store in a temporary directory and compares entity names, attribute names, and attribute value types. The M1 test compared a static declaration to itself and could not fail; this one can.

7. **Verification commands become scripts.** `scripts/focused.sh` runs the app unit suite only (the per-atom loop); `scripts/smoke.sh` builds, launches with `-praxmodoro-ephemeral-store`, confirms the process and window, and quits. Both are documented in the README next to the existing commands, so the per-atom and changed-surface checks are reproducible by name instead of by remembered argv.

## Data boundaries

No new persisted field, no new `SessionEvent` kind, no new model. `SessionSnapshot` is a derived value that never round-trips to storage. The return overlay's state is in-memory. Nothing in this change opens a socket, reads a calendar, or writes outside the app's Application Support directory — the existing `NetworkSilenceTests` structural harness continues to cover the new sources because it scans the whole `Sources` tree.

## Dependency provenance

No new package. The capsule and popover are SwiftUI scenes; the physics stays the existing `FieldPhysics`/`FieldModel` port golden-tested against `companion-physics.js`. `ImageRenderer` is a platform API. This preserves the M1 dependency audit conclusion (research w2-effects-dependency-audit-004): no third-party rendering or effect package.

## Rollback

Every atom is one commit against a feature branch. The scene additions are additive: removing the `MenuBarExtra` and capsule `Window` scenes from `PraxmodoroApp.body` and reverting `FocusSurface` to its local formatter restores M1 behavior exactly. The store is untouched, so there is no migration to reverse and no user data at risk.

## Verification strategy

- **Per atom:** the named failing test first, observed red, then minimal implementation, then `./scripts/focused.sh` green.
- **Single-source-of-truth:** one behavioral test asserting the three surfaces' rendered strings are identical from one snapshot, plus one structural test asserting no surface source contains a timer/counter construction and that the snapshot accessor is the only source of rendered remaining time.
- **Accessibility:** render-level pixel probes (transparency, contrast) plus the retained structural scans plus the Reduce-Motion physics-absence assertions extended to the new surfaces.
- **Interface:** UI tests drive begin, ⌘K, check-in `1`–`4`, `R`, ⌘N, and the capsule command as real key events against a hermetic ephemeral store, and assert the first-run launch state.
- **Whole change:** `./scripts/verify-project.sh` (regeneration staleness gate, both package suites, strict format lint, build, full signed suite including UI tests), `npm run spec:validate` strict, `./scripts/smoke.sh`, and an independent fresh-context validator against `SPEC.md` before archive.
