# Second Revision Reconciliation

## Gate state

The first revised-plan council returned three `NO_GO` verdicts. After the corrections below and a
second semantic hardening pass, the fresh toolchain, policy/privacy, and trace council each
returned `GO` at 2026-07-20T15:34:29Z. Implementation was still 0/21 at acceptance.

## Findings and binding corrections

| Finding | Correction | Local evidence before fresh review |
|---|---|---|
| Repo-local executable paths failed from checkout paths containing spaces | Quote every XcodeGen binary expansion in command position | All 23 scaffold Bash/Swift fences parse; targeted unquoted-path scan is empty |
| App-test evidence could prove the UI test but not a named app-unit test or aggregate status | Require both named test methods plus `result == Passed`, at least three executed tests, zero failures, and passed equals total from the Xcode 26.6 summary schema | `xcresulttool ... summary --schema` confirms `result`, `totalTestCount`, `passedTests`, and `failedTests` |
| OpenSpec retained Homebrew and blocker language | Require checksum-verified repo-local XcodeGen; remove blocker from every edition pending a separate approved add-on spec | Strict OpenSpec validation passes 1/1 with zero issues; contradiction scan is empty |
| Descriptor decisions could silently default | Remove descriptor defaults and compare the complete exact descriptor dictionary in tests | Combined production edition snippets type-check with warnings as errors |
| Grants could be memberwise-forged or accepted before issue time | Use a private initializer, DEBUG-only test validator, and enforce `issuedAt <= now < expiresAt` in validation and resolution | Production snippets type-check under `-D DEBUG`; tests include future-issued and expired fixtures |
| Snapshot kept only one missing prerequisite | Store a set of every simultaneous missing reason per unavailable capability | Calendar and iCloud fixtures assert exact reason sets |
| Consent defaults/schema were not structurally closed | Remove caller-settable diagnostics/sync defaults and unify all managed inputs under one exhaustive typed schema | Tests assert exact field set, populated-field coverage, provenance, and recommendation-no-consent behavior |
| Session downgrade lease was freely constructed and ignored concurrent changes | Introduce a private commit receipt and opaque lease tied to session ID/revision/time/snapshot; preserve only for the exact singleton expiry reason | Tests reject revision zero and enumerate every immediate plus combined reason |
| Trace counts/files/commits diverged | Split 56 EARS criteria from 12 assumptions, add G-003 to atom 2.2, add `AppPaths.swift`, and align commit messages | `jq` trace assertions and `git diff --check` pass |

## Fresh acceptance rule

Three independent `GO` verdicts with no Critical or Major issue closed the planning gate.
An empirical Task 1.1 XCUITest environment failure remains a legitimate future RED/GREEN blocker
and must never be converted into a skipped or unsigned-test green.
