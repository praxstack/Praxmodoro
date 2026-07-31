# Atom 2.2 scratch evidence

## Verdict

**CORE/PACKAGE VERIFIED AFTER REVIEW REMEDIATION; APP/UI REGRESSION BLOCKED BY LOCKED MAC.**
Validated grant value types, fail-closed production resolution, typed policy precedence,
independent implementation/runtime availability, and expiry-only session downgrade are
implemented in the isolated scratch worktree. The package, release, public-API, generator, build,
smoke, OpenSpec, diff, dependency, and secret gates pass. The atom remains uncommitted and
unchecked because its unchanged signed app/UI regression cannot run while the Mac is locked.

Worktree:
`/Users/prax/Development/Praxodoro/.worktrees/atom-1-2-scratch`

## RED

The exact planned `EntitlementSnapshotTests.swift` was created before production symbols, then:

```bash
swift test --package-path Packages/PraxodoroCore --filter EntitlementSnapshotTests
```

- Exit status: `1`.
- Output named `EntitlementSnapshotTests` and missing `EntitlementEvidenceSource`,
  `UntrustedEntitlementClaim`, `VerifiedGrant`, `CapabilityEnvironment`, policy types,
  `resolveProduction`, `resolveValidatedForTesting`, session lease/receipt, and `transition`.
- This was the required compile-time behavior RED, not a syntax-only or zero-selected-tests result.

## Implementation

- Created `EntitlementSnapshot.swift` with immutable `Equatable`/`Sendable` value types.
- Kept `VerifiedGrant`, `SessionStartCommitReceipt`, and `SessionCapabilityLease` internal with
  private initializers; only DEBUG test factories can create validation evidence/commit receipts.
- Extended `ProductRules` with a public resolver that always fails unverified claims closed to
  Lite and a non-public validated path for downstream testing.
- Required `issuedAt <= validation/resolution time < expiresAt` and coherent source/tier pairs.
- Recorded granted versus available capabilities and every simultaneous missing adapter,
  runtime-service/model, authorization, platform, distribution, and managed-policy prerequisite.
- Resolved consent using OS safety, enforced managed restrictions, explicit user choice,
  recommendation, and fixed-off app defaults while keeping coach cadence personal.
- Bound a session lease to an opaque committed session ID/revision/commit time and the complete prior
  entitlement snapshot. Transition preservation requires same-evidence expiry, exact source,
  issue/expiry times, limits, environment, policy, active receipt, and lease.

## Strengthened acceptance coverage

Caller and independent reviews found that the accepted test draft did not directly prove every
claim in its own GREEN contract. The executable plan and test were strengthened before final
verification to:

- exercise all four `EntitlementEvidenceSource` values as untrusted public claims;
- retain authorization, platform, distribution, adapter, and policy failures simultaneously;
- prove `.recommendedManaged` provenance for a recommendation that opts out but never opts in;
- use reflection to prove managed configuration has exactly the approved fields and policy
  defaults structurally contain only personal coach cadence, not consent booleans; and
- reject expiry preservation when otherwise matching evidence carries different entitlement
  limits, evidence source, issue time, or expiry time;
- reject a lease paired with the same session ID but a different revision or commitment time;
- model adapter implementation and current runtime service/model availability independently;
- assert no reevaluation for permanent expired/verifier-unavailable fallback, while a future-issued
  grant reevaluates at its issue time; and
- assign capability-only observable publication to atom 5.2 under new criterion G-007, while
  downgrade data readability/exportability remains explicitly owned and proved by atom 6.3.

The runtime/reevaluation remediation started with a focused compile-time RED: the updated tests
exited `1` on missing `runtimeAvailableCapabilities` and `.runtimeUnavailable` before production
types changed. This was followed by the minimal environment/reason/resolver change and GREEN.

The final test, production source, and plan code blocks are byte-identical after formatting.

## Independent remediation reviews

- Quality review: **PASS**, with no Critical, Major, or Minor findings after fresh focused/full
  tests, release/format/OpenSpec/diff/public-symbol checks.
- Canonical trace review: initial **FAIL** exposed missing capability-publication ownership,
  downgrade-data ownership, stale topology, obsolete `.historySync` wording, and an omitted
  platform-eligibility dimension. After SPEC/PRD/task/design/Blueprint reconciliation, the final
  re-review returned **PASS** with no remaining finding.
- Neither reviewer ran UI, authentication, or lock operations. The app/UI gate is still missing,
  and this scratch atom remains todo, unchecked, uncommitted, and unintegrated.

## Focused GREEN

```bash
swift test --package-path Packages/PraxodoroCore --filter EntitlementSnapshotTests
```

- Exit status: `0`.
- Swift Testing: `13 tests` in `1 suite`, all passed.
- The parameterized public-claim test executed four cases: none, StoreKit, signed Enterprise
  license, and static development.
- Named coverage includes Lite baseline; impossible validation states; granted/available
  separation; every simultaneous missing reason; implemented-but-runtime-unavailable behavior;
  expired/future-issued rejection and reevaluation; visible
  development evidence; all policy provenance; fixed-off defaults; personal cadence; exhaustive
  managed/audit schemas; and exact committed-session downgrade constraints.

## Full package and build verification

```bash
swift test --package-path Packages/PraxodoroCore
```

- Exit status: `0`; `20 tests` in `2 suites`, all passed.

```bash
bash scripts/verify-project-generation.sh
```

- Exit status: `0`.
- Output:
  `PROJECT_GENERATION_OK xcode=26.6 swift=6.3.3 xcodegen=2.46.0 swift-format=6.3.0`.

```bash
xcodebuild -project Praxodoro.xcodeproj -scheme Praxodoro \
  -destination 'platform=macOS' -derivedDataPath .build/DerivedData \
  build CODE_SIGNING_ALLOWED=NO
```

- Exit status: `0`; `** BUILD SUCCEEDED **` under Swift 6 and warnings-as-errors.

```bash
swift build --package-path Packages/PraxodoroCore --configuration release
swift package --package-path Packages/PraxodoroCore dump-symbol-graph
```

- Release build passed.
- Public symbol graphs contain none of `VerifiedGrant`, `SessionStartCommitReceipt`,
  `SessionCapabilityLease`, `validatedForTesting`, or `resolveValidatedForTesting`.

## Regression and security verification

- Isolated smoke passed with termination `143` and a fatal-clean log:
  `.build/Smoke/scaffold-20260720T165141Z-48729.log`.
- Strict OpenSpec validation passed.
- `SPEC.md` and `prd.json` agree on 57 EARS criteria plus 12 documented assumptions; G-007 is
  mapped to atom 5.2, and G-004 data preservation remains mapped to atom 6.3 rather than 2.2.
- `git diff --check` passed.
- Production-source scan found no StoreKit/CloudKit import, UserDefaults, AppStorage, URLSession,
  or Network dependency; no production verifier or mutable license preference was introduced.
- A fresh 87.13 MB `gitleaks dir` scan found no leaks.
- Checkpoint hashes: `EntitlementSnapshot.swift`
  `91aed09daf3df2c18e55a6932c33b3b1bec659f4f19923e305c44ce90658046b`, `ProductRules.swift`
  `94fcfc51d16dfde30b96126a9835a19f124b787d37e17a0bfd47d340c474f3fb`, and tests
  `0487b4ad20b914662f967f90da2e730bae5b2c4dbc17098e9a7b54be8f066cfb`.

## Deliberately missing gate

`bash scripts/run-app-tests.sh` was not run. The Mac remains locked, and no signing/UI criterion,
authentication service, lock service, OpenSpec checkbox, PRD status, or commit was changed.
Complete atom verification still requires `APP_TESTS_OK` from a retained Passed `.xcresult` after
the Mac is unlocked.
