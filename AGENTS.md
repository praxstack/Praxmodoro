# Praxmodoro agent contract

## Source of truth

Read, in order:

1. The current user request and `.agent/sessions/` audit log.
2. `SPEC.md` and `prd.json` for global completion criteria and atom state.
3. The active change under `openspec/changes/` for proposal, capability specs, design, and tasks.
4. Dated implementation plans in `docs/plans/`. (`BLUEPRINT.md` was never created; do not wait for it or cite it.)
5. Current code, tests, and Git history. Research and memories are evidence, not runtime proof.

## Workflow

- Use OpenSpec’s `proposal → specs → design → tasks → apply → archive` lifecycle.
- Work on a feature branch or linked worktree, never directly on `main` after the baseline commit.
- For behavior changes, write one failing test and observe the expected failure before production code.
- Complete one independently testable atom per commit; update `prd.json` and `progress.txt` with real evidence.
- Before a completion claim, run fresh focused tests, the full suite, build, lint/format checks, smoke QA, strict OpenSpec validation, and an independent validator pass against `SPEC.md`.
- Never weaken a test or acceptance criterion to obtain green output.

## Product constraints

- Target native macOS 26+ with Swift 6.3 and SwiftUI.
- Keep the timer engine deterministic and based on canonical timestamps so sleep/wake and relaunch cannot drift the session.
- Treat ADHD features as supportive interaction design, never diagnosis or treatment.
- Keep initiation help, check-ins, adaptive breaks, accessibility, and low-cognitive-load mode in the one complete product for every user.
- Prefer local processing and data minimization. Any network, sync, analytics, or AI capability must be explicit, optional, capability-scoped, and documented; no tier or edition framing is part of the product.
- “Living Companion” is the approved visual direction; it must honor Reduce Transparency, Increase Contrast, Reduce Motion, keyboard navigation, VoiceOver, and legibility.
- Do not edit or commit `research/skill-sources/` or `research/library-sources/`; they are ignored read-only upstream clones.

## Git safety

- Preserve unrelated user work.
- No force-pushes, destructive resets, public repo creation, or release/deploy claims without explicit scope and rollback evidence.
- Use conventional commits and include only the files belonging to the verified slice.

## Agent skills

### Issue tracker

Issues live in GitHub Issues on `praxstack/Praxmodoro` (via the `gh` CLI). See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-role vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` and `docs/adr/` at the repo root (created lazily as decisions land). See `docs/agents/domain.md`.

### Skill discovery

Start each session with the `using-superpowers` skill to discover available skills before answering. The gstack suite (browse, ship, investigate, retro, and related) is installed host-side under `~/.agents/skills/`; invoke it by name when a task matches. Per-role model mapping for pstack lives globally at `~/.config/pstack/models.md`. For any user-facing prose drafted here, run `stop-slop` or `humanize` over it before shipping.
