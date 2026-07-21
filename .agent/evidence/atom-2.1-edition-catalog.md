# Atom 2.1 safe edition-catalog evidence

## Verdict

**VERIFIED, INDEPENDENTLY REVIEWED, AND COMMITTED.** Commit
`0b1316aa7290d114215a1b9ee9876746dfad7036` (`feat: define safe edition access catalog`)
contains the accepted Atom 2.1 milestone. The package defines the complete ungateable Lite inventory and every
optional Pro/Enterprise capability descriptor required by Atom 2.1. Focused, full-package, native
build/test, smoke, generation, OpenSpec, lint, diff, and secret gates pass. Independent standards,
spec, and receiving reviews returned READY with zero findings. The shipping council's conditional
transaction gates, exact staged-scope audit, and milestone commit were completed.

Supported acceptance criteria (component evidence, not final acceptance): `G-001`, `G-002`,
`G-006`.

Candidate base: `e2a537c` (`chore: enforce native project quality gates`).

## RED provenance

The accepted failing test was observed in the isolated scratch worktree before production types
existed. `swift test --package-path Packages/PraxodoroCore --filter ProductRulesTests` exited `1`
and named the missing `RequiredLiteFeature`, `ProductCapability`, `CapabilityDescriptor`, and
`ProductRules` symbols. The durable record is `progress.txt` at the `2.1-scratch | RED` entry.

## Integrated candidate

- `ProductCapability.swift` defines three tiers, 29 unconditional Lite features, 12 optional
  capabilities, independent authorization/platform/distribution dimensions, explicit data access,
  downgrade behavior, and adapter availability.
- `ProductRules.swift` provides one exhaustive descriptor per optional capability and derives tier
  eligibility without scattered edition-name branching.
- `ProductRulesTests.swift` asserts the exact Lite inventory, exact descriptor map, exact Pro and
  Enterprise unions, prerequisite independence, the privileged-blocker exclusion, and the
  Enterprise personal-data boundary.
- No entitlement evidence, production resolver, managed-policy resolution, session lease, or other
  Atom 2.2 behavior is present.

Accepted checkpoint hashes:

- `ProductCapability.swift`: `819a85059afbab35d80fad474da910c6c9a5e1466a891cbeaeec1a8136010632`
- `ProductRules.swift`: `1482ee17b2f4044b2a52c9a407ce5869783de4be2a899fa22b8277dd603e9695`
- `ProductRulesTests.swift`: `f3d245775f8c8ec80bbd35bbb48f9e243fd168efc3faecc9cca1de579ae529e0`

## Fresh verification

- Focused package suite: exit `0`; 6 tests in `ProductRulesTests` passed.
- Full package suite: exit `0`; 7 tests passed, including the scaffold identity test.
- Deterministic fixture audit: `required_lite_fixture_count=29` and
  `optional_descriptor_fixture_count=12`.
- Production privileged-blocker scan: no match.
- Atom 2.2 symbol-leak scan: no match.
- `bash scripts/verify-project-generation.sh`: exit `0`;
  `PROJECT_GENERATION_OK xcode=26.6 swift=6.3.3 xcodegen=2.46.0 swift-format=6.3.0`.
- `bash scripts/verify-scaffold.sh`: exit `0`;
  `SCAFFOLD_OK xcode=26.6 swift=6.3.3 xcodegen=2.46.0 targets=3`.
- Unsigned Xcode build: exit `0`; `** BUILD SUCCEEDED **`; project and package compile with Swift 6
  and warnings-as-errors.
- `bash scripts/run-app-tests.sh`: exit `0`; `APP_TESTS_OK total=3 passed=3`. The retained bundle is
  `.build/TestResults/Praxodoro-20260721T114025Z-84504.xcresult`; the normalized receipt is
  `.agent/evidence/atom-2.1-app-test-receipt.json`.
- `bash scripts/smoke-scaffold.sh`: exit `0`; the isolated app stayed live for the five-second probe
  and terminated deliberately with status `143`.
- `npm run spec:validate`: strict OpenSpec result `1 passed, 0 failed`.
- `openspec doctor --json`: repo-local root healthy with no findings.
- Xcode project inventory exposes the Praxodoro app, unit-test, UI-test targets, and shared schemes.
- `bash -n`, ShellCheck, `git diff --check`, and gitleaks: exit `0`.

## Spec-workflow audit note

Official OpenSpec v1.6.0 conformance is healthy and the six core Codex workflows are installed. A
separate spec-creator review found missing portable typed domain tables, configuration defaults,
the exhaustive session transition/error matrices, and criterion-to-test traceability for later
atoms. Atom 2.1 is not affected because its accepted exact-code plan fully defines this candidate;
the autonomous plan now blocks Atom 3.1 until those semantic contract gaps are repaired.

## Independent review and council

- Standards review: READY, zero findings. The apparent descriptor duplication is the intentional
  independent exact-value test oracle required by the accepted plan.
- OpenSpec/spec review: READY, zero missing requirements, scope creep, wrong behavior, or Atom 2.2
  leakage.
- Receiving review: READY, zero findings; reproduced the three accepted source hashes and both raw
  test-artifact hashes and froze the five-file technical/evidence allowlist.
- Quick shipping council: Torvalds, Musashi, and Feynman independently returned
  `ACCEPT_CONDITIONALLY`, preserved that position under anonymized anti-conformity review, and an
  independent Chairman set the transaction gates in
  `.agent/council/2026-07-21-atom-2.1-commit-council.md`.

## Recorded pre-commit kill criteria (satisfied)

Do not credit or commit Atom 2.1 if review finds an unresolved finding; if a fresh gate fails; if
any accepted checkpoint hash changes without a new reviewed plan; if Atom 2.2 behavior leaks into
the candidate; if staged paths exceed the reviewed allowlist; or if OpenSpec/PRD/progress claim
completion before review, council, and transaction gates close.
