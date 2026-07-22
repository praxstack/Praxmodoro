## ADDED Requirements

### Requirement: Native reproducible project
The repository SHALL contain a reproducible macOS 26+ Xcode project generated from a human-readable project specification and buildable by Xcode 26.6 with Swift 6.3.

#### Scenario: [MAD-S001] Clean project generation
- **WHEN** a clean checkout installs the documented XcodeGen 2.46.0 tool and runs the generation command
- **THEN** it produces the committed Praxodoro project structure without manual Xcode file edits

#### Scenario: [MAD-S002] Clean command-line build
- **WHEN** the documented unsigned local Debug build command runs on the supported toolchain
- **THEN** the Praxodoro app target and internal package compile with zero errors and no new warnings

### Requirement: One app and one deep internal package
The first implementation SHALL use one native app target plus one internal `PraxodoroCore` Swift package whose deep boundaries are Session, Runtime, and Entitlements rather than one package per screen.

#### Scenario: [MAD-S003] Target inventory
- **WHEN** project and package manifests are inspected
- **THEN** all views and native scenes depend on the same core product, and no Lite/Pro/Enterprise duplicate app codebase or screen package exists

### Requirement: Strict concurrency and actor isolation
The project SHALL enable Swift 6 language mode and strict concurrency, SHALL serialize runtime session intents in one actor-isolated engine, and SHALL keep pure state reduction independently testable.

#### Scenario: [MAD-S004] Concurrency build
- **WHEN** app and core targets compile under Swift 6 strict concurrency settings
- **THEN** the build reports no data-race isolation error or newly introduced concurrency warning

### Requirement: Local-first persistence adapters
The app SHALL place SwiftData behind a repository contract and SHALL provide an in-memory adapter for deterministic tests and previews.

#### Scenario: [MAD-S005] Repository contract suite
- **WHEN** the same repository contract tests run against in-memory and temporary SwiftData adapters
- **THEN** both satisfy revision checks, atomic snapshot/event commit, zero-or-one active record, and failure behavior

### Requirement: Shared main and menu-bar runtime
The app SHALL provide a `WindowGroup` and `MenuBarExtra` that resolve the same engine instance from an app container.

#### Scenario: [MAD-S006] Scene integration test
- **WHEN** the app launches both scenes and a session is started from either surface
- **THEN** both observe the same session identifier and monotonically increasing state revision

### Requirement: Test-first implementation gate
Every behavior implementation SHALL begin with a focused automated test that is observed failing for the expected missing behavior before production code is written.

#### Scenario: [MAD-S007] Task evidence
- **WHEN** an implementation task is marked complete
- **THEN** its report and Git history identify the red command/output, minimal green change, focused green command/output, broader regression command, smoke result, and commit

### Requirement: Full verification workflow
The repository SHALL provide commands and CI steps for strict OpenSpec validation, formatting, static analysis, secret scanning, core unit tests, repository tests, app build, UI/accessibility tests where automatable, zero-network/privacy verification, energy/performance budgets, and a launch smoke test.

#### Scenario: [MAD-S008] Pull-request workflow
- **WHEN** the macOS CI workflow runs for a proposed change
- **THEN** every configured spec, format/static, test, build, secret, zero-network/privacy, energy/performance, and smoke gate executes on a supported macOS runner and the workflow fails if any required gate fails

#### Scenario: [MAD-S009] Local verification
- **WHEN** a developer runs the documented verification script
- **THEN** it executes the same mandatory spec, format/static, test, build, secret, zero-network/privacy, energy/performance, and smoke gates without requiring production credentials

### Requirement: Pinned and justified development dependencies
Every non-Apple build or development dependency SHALL have an exact version, canonical source, license, integrity or resolved commit where available, purpose, upgrade path, and removal/fallback plan documented.

#### Scenario: [MAD-S010] XcodeGen provenance
- **WHEN** dependency provenance is audited
- **THEN** XcodeGen is recorded as version 2.46.0 from `https://github.com/yonaskolb/XcodeGen`, MIT licensed, development-only, and unnecessary at app runtime

#### Scenario: [MAD-S011] OpenSpec provenance
- **WHEN** specification-tooling provenance is audited
- **THEN** `@fission-ai/openspec` is recorded as version 1.6.0 from `https://github.com/Fission-AI/OpenSpec`, MIT licensed, development-only, integrity-locked, and unnecessary at app runtime

#### Scenario: [MAD-S012] Unapproved dependency
- **WHEN** a new package lacks complete provenance or a justified boundary
- **THEN** CI or review blocks its adoption until the dependency decision is complete

### Requirement: Deterministic launch smoke test
The project SHALL provide an unsigned local smoke path that builds the `.app`, launches it with isolated test storage, verifies the process and primary window or accessibility element, and terminates it without modifying the user's normal data.

#### Scenario: [MAD-S013] Fresh smoke launch
- **WHEN** the smoke command runs after a clean Debug build
- **THEN** a Praxodoro process launches with isolated storage, exposes the initiation surface, logs no fatal error, and terminates successfully

### Requirement: Documentation and durable workflow state
The repository SHALL keep setup, architecture, data dictionary, design tokens, edition matrix, build/test/smoke commands, OpenSpec state, `SPEC.md`, `BLUEPRINT.md`, `prd.json`, `progress.txt`, implementation plan, and durable decisions current with the code.

#### Scenario: [MAD-S014] Fresh-context acceptance audit
- **WHEN** a new validator opens the final repository tree without prior conversation context and audits acceptance
- **THEN** the documented source order identifies the active change, next unfinished atom, exact commands and known failures, and the validator compares all 57 EARS criteria with current code/evidence or an explicit incomplete owner without relying on chat memory

### Requirement: Shipping boundary honesty
This change SHALL NOT claim a public GitHub repository, remote push, signed/notarized build, App Store submission, production deployment, cloud backend, payments, or released Enterprise service unless each external atom is separately performed and verified.

#### Scenario: [MAD-S015] Local completion
- **WHEN** all local implementation criteria pass but external shipping atoms were not requested or performed
- **THEN** the handoff reports a verified local app and explicitly lists public remote, signing, notarization, distribution, and services as not shipped
