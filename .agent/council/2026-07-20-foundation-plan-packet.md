# Foundation Plan Council Packet

## Decision Requested

Decide whether Praxodoro may move from spec/plan into the first four native implementation
atoms (`1.1`, `1.2`, `2.1`, `2.2`). Return `GO`, `GO_WITH_REQUIRED_CHANGES`, or
`NO_GO`; do not implement or edit files.

## Authoritative Inputs

- `SPEC.md`: global completion contract with 56 EARS criteria and 12 separate assumptions.
- `BLUEPRINT.md`: architecture, state, timing, data, error, render, and rollback contracts.
- `prd.json`: 21-atom dependency graph and evidence slots.
- `openspec/changes/build-native-praxodoro/`: proposal, design, six capability specs, and tasks.
- `docs/superpowers/plans/2026-07-20-native-foundation.md`: exact-code plan under review.
- `docs/planning/premortem.md`: failure hypotheses and council triggers.
- `docs/planning/devils-advocate.md`: scope and proof objections already raised.
- `.agent/recon/adhd-privacy-test-strategy.md`: product/privacy/test review.
- `design-mocks/hallmark/`: approved Liquid Instrument prototype evidence.

## Frozen Product Decisions

- Native macOS 26+, one app target, one internal Swift package.
- Lite contains the full local ADHD-aware focus/recovery/accessibility/privacy/export/delete
  core, including Gentle, Classic, Flow, and Recovery First presets.
- Pro and Enterprise are capability supersets. Missing, invalid, or expired paid evidence
  fails closed to Lite without hiding local data.
- Raw capacity and check-in answers are session-only by default.
- The first slice has no StoreKit, CloudKit, EventKit, App Intents, Foundation Models,
  blocker extension, Enterprise service/backend, or third-party runtime-effects library.
- XcodeGen 2.46.0 is a development-only generator; the generated project is committed and
  must regenerate without a diff.
- TDD is mandatory for behavior. Configuration generation requires an observed failing
  verifier before generation.

## Environment Evidence

- Xcode 26.6; Swift 6.3.3; Xcode-bundled `swift-format` 6.3.0.
- OpenSpec 1.6.0 is repo-local and strict validation currently passes.
- XcodeGen is not installed yet. The first implementation atom must observe that verifier
  failure, then install and prove exact version 2.46.0 before use.
- Worktree: `/Users/prax/Development/Praxodoro/.worktrees/native-app` on
  `feat/native-app`, based on `9a910325c09ed5288c262a5653f561286fdd196e`.

## Required Review Questions

1. Do the exact Swift, Swift Testing, SwiftPM, XcodeGen YAML, build, smoke, and formatting
   instructions compile or execute as written on the declared toolchain?
2. Does the test sequence actually compile and exercise each produced target, or could a
   false green leave app/unit/UI test code unbuilt?
3. Are capability, entitlement, managed-policy, expiry, and active-session downgrade rules
   type-correct and fail-closed without paywalling Lite recovery support?
4. Does any foundation interface prematurely commit the later engine, data, UI, StoreKit,
   CloudKit, Enterprise, or visual implementation?
5. Are the dependency provenance, generated-project reproducibility, accessibility honesty,
   privacy defaults, and rollback claims falsifiable?
6. Identify every critical or major defect with file/section evidence and an exact required
   correction. Separate blockers from improvements.

## Decision Rule

Any unresolved critical defect is `NO_GO`. A major defect with a concrete local correction is
`GO_WITH_REQUIRED_CHANGES`, and the correction must be made and revalidated before code.
Suggestions that do not affect correctness, safety, proof, or frozen product decisions do not
block the first atom.
