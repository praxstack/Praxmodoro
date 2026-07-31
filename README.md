# Praxodoro

Praxodoro is a native macOS focus timer and non-clinical ADHD-aware focus coach. It combines low-friction task initiation, gentle check-ins, adaptive breaks, and local-first review with the advanced “Liquid Instrument” visual language documented in the Hallmark mock dossier.

## Current state

The product research and interactive visual mocks are complete. Native implementation is beginning through an OpenSpec change and a test-first autonomous workflow; no shipping app or Enterprise service is claimed yet.

## Editions

- **Lite:** complete local focus loop, initiation support, check-ins, adaptive breaks, accessibility modes, menu-bar controls, and local review.
- **Pro:** advanced local insights, richer automations/integrations, optional sync, and deeper customization.
- **Enterprise:** the same native client with managed policy, audit/export, deployment, and identity integration boundaries. Team/cloud services are separate deliverables, not hidden inside the scaffold.

Core accessibility and ADHD-aware focus support are not paywalled.

## Repository map

- `research/pomodoro-landscape-20260720/` — sourced product and platform research.
- `design-mocks/hallmark/` — interactive Hallmark mocks, screenshots, and design dossier.
- `openspec/` — canonical product specs and active change artifacts.
- `.agent/sessions/` — continuous autonomous build audit trail.
- `SPEC.md`, `BLUEPRINT.md`, `prd.json`, `progress.txt` — durable completion contract and execution state.

## Specification commands

```bash
npm install
npm run spec:list
npm run spec:validate
```

OpenSpec is pinned to 1.6.0. The native foundation commands below exercise generator,
verification, test, build, and smoke paths.

## Native foundation commands

```bash
bash scripts/bootstrap-xcodegen.sh
bash scripts/verify-scaffold.sh
bash scripts/verify-project-generation.sh
swift test --package-path Packages/PraxodoroCore
xcodebuild -project Praxodoro.xcodeproj -scheme Praxodoro \
  -destination 'platform=macOS' -derivedDataPath .build/DerivedData \
  build CODE_SIGNING_ALLOWED=NO
bash scripts/run-app-tests.sh
bash scripts/smoke-scaffold.sh
```
