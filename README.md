# Praxodoro

Praxodoro is a native macOS focus timer and non-clinical ADHD-aware focus coach. It combines low-friction task initiation, gentle check-ins, adaptive breaks, and local-first review with the advanced “Liquid Instrument” visual language documented in the Hallmark mock dossier.

## Current state

Research is complete, three visual directions were mocked at equal fidelity, and **Living Companion** was approved as the base direction (2026-07-30). Milestone M1 (app scaffold + core loop) is specified in the OpenSpec change `add-app-scaffold-core-loop`; native implementation is beginning against that spec. No shipping app or Enterprise service is claimed yet.

## Editions

- **Lite:** complete local focus loop, initiation support, check-ins, adaptive breaks, accessibility modes, menu-bar controls, and local review.
- **Pro:** advanced local insights, richer automations/integrations, optional sync, and deeper customization.
- **Enterprise:** the same native client with managed policy, audit/export, deployment, and identity integration boundaries. Team/cloud services are separate deliverables, not hidden inside the scaffold.

Core accessibility and ADHD-aware focus support are not paywalled.

## Repository map

- `research/pomodoro-landscape-20260720/` — sourced product and platform research.
- `design-mocks/living-companion/` — the approved direction: interactive mocks and the companion-field physics contract.
- `design-mocks/hallmark/`, `design-mocks/focus-observatory/` — comparative direction records (A and C).
- `design-mocks/direction-gate/` — side-by-side comparison and the recorded direction decision.
- `openspec/` — OpenSpec configuration and change artifacts (active change: `add-app-scaffold-core-loop`).
- `.agent/sessions/` — continuous autonomous build audit trail.
- `progress.txt` — append-only execution log.

`SPEC.md` (completion contract) and `prd.json` (atom state) now exist and govern milestone M1. `BLUEPRINT.md` remains a planned artifact for the implementation phase.

## Specification commands

```bash
npm install
npm run spec:list
npm run spec:validate
```

OpenSpec is pinned to 1.6.0. Native build and test commands will be added with the first app scaffold.
