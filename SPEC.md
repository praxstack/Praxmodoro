# SPEC.md — Praxmodoro completion contract

The durable definition of done. The independent validator checks work against this file, not against session claims. Detailed binary requirements live in the OpenSpec capability specs; this file states the contract's shape and the global gates.

## Product

Praxmodoro: native macOS focus timer and non-clinical ADHD-aware focus coach. macOS 26+, Swift 6.3, SwiftUI, local-first. One product: every capability ships to every user; capability keys remain internal provenance switches and are never paywallable (edition framing struck by owner decision 2026-08-23, issue #34). Initiation help, check-ins, adaptive breaks, accessibility, and low-cognitive-load modes are built in, always.

Visual direction: **Living Companion** (approved 2026-07-30, **re-affirmed 2026-08-12** against three divergent alternatives — decision record `docs/decisions/2026-08-12-direction-reaffirmed.md`; binding reference `design-mocks/living-companion/`, physics contract `companion-physics.js`). Evidence roots: `research/pomodoro-landscape-20260720/` for product claims, the mocks for visual decisions.

## Milestone M1 — app scaffold + core loop (COMPLETE 2026-07-31)

Governed by OpenSpec change `add-app-scaffold-core-loop` (archived `2026-07-31-add-app-scaffold-core-loop`). Independent fresh-context validation confirmed all seven gates PASS at `d56949d`. M1 was complete when, and only when:

1. Every EARS scenario in `openspec/changes/add-app-scaffold-core-loop/specs/{app-scaffold,timer-engine,focus-loop-ui,session-persistence}/spec.md` is covered by an automated test that passes.
2. Every task in that change's `tasks.md` is checked, each with its red-then-green evidence recorded in `prd.json` and `progress.txt`.
3. A clean clone builds, tests, and runs with only the README-documented commands.
4. The timer survives sleep/wake and relaunch with remaining time exactly derived from canonical timestamps (zero tick drift).
5. Reduce Motion / "Motion: still" produces the total physics standdown; Reduce Transparency and Increase Contrast alternates render; the full keyboard loop and VoiceOver labels pass.
6. The copy-tone lint (no medical/diagnostic/judgment claims), no-network harness, and never-paywalled-set validation all pass.
7. `npm run spec:validate` passes strict, and an independent validator session confirms 1–6 from a fresh context using only this file, the change artifacts, and the repo.

## Milestone M2 — companion surfaces (in progress, one gate blocked 2026-08-04)

Governed by OpenSpec change `add-companion-surfaces`. M2 is complete when, and only when:

1. Every EARS scenario in `openspec/changes/add-companion-surfaces/specs/{companion-surfaces,focus-loop-ui,session-persistence,app-scaffold}/spec.md` is covered by an automated test that passes.
2. The menu-bar popover, floating focus capsule, and return overlay all render one canonical engine-derived session state; no surface counts time, proven behaviorally (a frozen input must produce an unchanged rendering after real time passes), not only by source scanning.
3. The four M1 hardening follow-ups are closed: render-level Reduce-Transparency/Increase-Contrast verification; two-configuration schema parity against live containers; keyboard UI coverage for ⌘K, check-in 1–4, `R`, ⌘N and the capsule toggle as real key events; a launch-time first-run assertion.
4. Complete accessibility alternates ship in the same change: Reduce Motion standdown proven on every companion surface in both directions, VoiceOver labels, full keyboard paths.
5. `./scripts/verify-project.sh` exits 0 and `./scripts/smoke.sh` exits 0.
6. `npm run spec:validate` passes strict, and an independent validator session confirms 1–5 from a fresh context.

**Status 2026-08-22.** Gate 2's no-second-clock defense survived six adversarial defeats being closed against it (full history in `prd.json` / `progress.txt`). The whole-change independent validator at HEAD `9a6dc8c` on 2026-08-13 confirmed C1–C4 and C6 pass, including the UI half of gate 3 actually executing — `verify-project.sh` exited 0 end to end once the host condition cleared. C5 failed on its bookkeeping clause only: literal one-commit-per-atom is unmeetable without rewriting the per-defeat commit trail that makes the C2 guarantee trustworthy. On 2026-08-22 the criterion owner granted the amendment recorded in `prd.json` (`commitMapping.proposedAmendment`): C5 now reads "every atom is traceable to one or more conventional commits, with any atom-to-commit deviation documented and justified."

**Remaining for M2 close:** an independent fresh-context re-validation against the amended criterion, then archive of `add-companion-surfaces`; `add-session-settings` tasks 9.2–9.3 gate that change's own archive. Tracked as issue #7.

## Charted next (2026-08-23)

Between M2 close and M3 sit two charted bodies of work. Detail lives on the issue tracker; each arrives as its own OpenSpec change with EARS specs, red-then-green atoms, and independent validation.

1. **Presence & continuity pack** (issue #27): global keyboard shortcuts (#19), recent-task reuse (#20), day timeline browser (#21), today-at-a-glance summary (#22); chimes default-on with the block-start cue (#18) ships independently; parking list (#30), music (#31), launch-at-login (#32), finite Session length (#33) are charted siblings.
2. **Enterprise-grade pass** (plan `docs/plans/2026-08-23-enterprise-grade.md`, issues #35–#53):
   - Data trust: persistence-failure surfacing (#35), persist-before-mutate (#36), VersionedSchema plan (#37), clock-anomaly honesty (#38), local diagnostics (#39), event-log indexing (#40), parked-thoughts defect (#41).
   - Companion presence grade: coach-initiated check-ins (#43), truthful break countdowns (#44), real step editing (#45), flow elapsed time (#46), capsule parity (#47), drift notes (#48), review totals (#49), fullscreen capsule (#42).
   - Distribution base (#50). Architecture prerequisites land first: payload vocabulary and restore extraction (#51), single break-end derivation (#52), surface routing discipline (#53).

## Later milestones (not yet specified)

M3 staged integrations (EventKit import, App Intents, richer local analytics) · M4 optional sync (CloudKit history, never live ticks) · M5 future content (insights, automations; cloud/team services are separate deliverables, if ever). Each arrives as its own OpenSpec change; nothing in this list is promised behavior until specified.

## Global invariants (hold at every milestone)

- Deterministic timing from canonical wall-clock timestamps; ticks are presentation only.
- Local-first: no network, account, or telemetry without a spec'd, explicit, optional, edition-gated opt-in.
- Non-medical positioning in every string; no punitive mechanics (streak loss, forced breaks, urgency, judgment of activity).
- Accessibility alternates are architecture, not polish; they ship in the same change as the feature they serve.
- One independently testable atom per commit; conventional commits; never weaken a test to go green.
