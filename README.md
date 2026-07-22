# Praxodoro

Praxodoro is a native macOS focus timer and non-clinical ADHD-aware focus coach. It combines low-friction task initiation, gentle check-ins, adaptive breaks, and local-first review with the advanced “Liquid Instrument” visual language documented in the Hallmark mock dossier.

## Current state

The product research and interactive visual mocks are complete. The native scaffold and edition-access foundation are verified in 4 of 21 OpenSpec atoms; the focus-session domain is next. No complete focus loop, shipping app, production paid verifier, or Enterprise service is claimed yet.

## Editions

- **Lite:** complete local focus loop, initiation support, check-ins, adaptive breaks, accessibility modes, menu-bar controls, and local review.
- **Pro:** advanced local insights, richer automations/integrations, optional sync, and deeper customization.
- **Enterprise:** the same native client with managed policy, audit/export, deployment, and identity integration boundaries. Team/cloud services are separate deliverables, not hidden inside the scaffold.

Core accessibility and ADHD-aware focus support are not paywalled.

## Repository map

- `research/pomodoro-landscape-20260720/` — sourced product and platform research.
- `design-mocks/hallmark/` — interactive Hallmark mocks, screenshots, and design dossier.
- `openspec/` — canonical product specs and active change artifacts.
- `docs/specification/session-domain-contract.md` — closed session types, defaults, exhaustive transitions, events/effects, and errors.
- `docs/specification/acceptance-trace.md` — all 57 EARS criteria mapped to OpenSpec scenarios, atoms, validation profiles, and evidence ownership.
- `SPEC.md`, `BLUEPRINT.md`, `prd.json`, `progress.txt` — durable completion contract and execution state.

## Specification commands

```bash
npm install
npm run spec:list
npm run spec:validate
npm exec -- openspec status --change build-native-praxodoro
npm exec -- openspec doctor --json
```

OpenSpec is pinned to 1.6.0. The native foundation commands below exercise generator,
verification, test, build, and smoke paths.

The pre-Atom-3.1 contract is ready once its OpenSpec scenarios and strict trace validation pass.
Each implementation atom uses a focused RED test, focused GREEN, one full regression run, and one
independent final review before its milestone commit. `progress.txt` and `finalized.html` change only
when behavior or accepted completion genuinely changes.

The active change is `build-native-praxodoro`. Repository-local workflow skills live under
`.codex/skills/openspec-*`; matching global Codex prompts, when installed, are invoked as
`/opsx:*`. This repository uses the core profile, so optional `/opsx:verify` is not required.
`openspec/specs/` is intentionally absent while this first change contains only ADDED capability
specs; canonical main specs appear when the change is synced/archived after all accepted tasks pass.

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
