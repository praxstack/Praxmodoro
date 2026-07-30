# Praxodoro

Praxodoro is a native macOS focus timer and non-clinical ADHD-aware focus coach. It combines low-friction task initiation, gentle check-ins, adaptive breaks, and local-first review with the advanced “Liquid Instrument” visual language documented in the Hallmark mock dossier.

## Current state

The product research and interactive visual mocks are complete. Native implementation has not started; it will begin with an OpenSpec change and a test-first autonomous workflow. No shipping app or Enterprise service is claimed yet.

## Editions

- **Lite:** complete local focus loop, initiation support, check-ins, adaptive breaks, accessibility modes, menu-bar controls, and local review.
- **Pro:** advanced local insights, richer automations/integrations, optional sync, and deeper customization.
- **Enterprise:** the same native client with managed policy, audit/export, deployment, and identity integration boundaries. Team/cloud services are separate deliverables, not hidden inside the scaffold.

Core accessibility and ADHD-aware focus support are not paywalled.

## Repository map

- `research/pomodoro-landscape-20260720/` — sourced product and platform research.
- `design-mocks/hallmark/` — interactive Hallmark mocks, screenshots, and design dossier.
- `openspec/` — OpenSpec configuration; canonical specs and change artifacts will live here once the first change is proposed.
- `.agent/sessions/` — continuous autonomous build audit trail.
- `progress.txt` — append-only execution log.

`SPEC.md`, `BLUEPRINT.md`, and `prd.json` — the durable completion contract and execution state referenced in `AGENTS.md` — are planned artifacts that have not been created yet.

## Specification commands

```bash
npm install
npm run spec:list
npm run spec:validate
```

OpenSpec is pinned to 1.6.0. Native build and test commands will be added with the first app scaffold.
