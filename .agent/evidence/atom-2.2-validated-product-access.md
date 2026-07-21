# Atom 2.2 validated product access evidence

## Verdict

**VERIFIED, INDEPENDENTLY REVIEWED, AND COMMITTED.** Commit
`35518ab7252160d8b3729859387c1be68b4a364b` (`feat: resolve validated product access`) contains
the accepted Atom 2.2 milestone. Atom 2.2 implements immutable entitlement snapshots, fail-closed
public resolution, validated internal grants, explicit policy provenance, independent availability
dimensions, and expiry-only committed-session preservation. The receiving-review audit and exact
staged-index checks completed before that commit.

Supported acceptance criteria (component evidence, not final acceptance): `G-002`, `G-003`,
`G-004`, `G-005`, `G-006`.

## Scope and accepted checkpoint

The implementation was integrated from the previously reviewed isolated scratch checkpoint. The
active files match its final recorded hashes:

- `EntitlementSnapshot.swift`: `91aed09daf3df2c18e55a6932c33b3b1bec659f4f19923e305c44ce90658046b`
- `ProductRules.swift`: `94fcfc51d16dfde30b96126a9835a19f124b787d37e17a0bfd47d340c474f3fb`
- `EntitlementSnapshotTests.swift`: `0487b4ad20b914662f967f90da2e730bae5b2c4dbc17098e9a7b54be8f066cfb`

`ProductCapability.swift` remained byte-identical to committed Atom 2.1 at
`819a85059afbab35d80fad474da910c6c9a5e1466a891cbeaeec1a8136010632`.

## Behavior proved

- Public untrusted claims, including development claims, cannot self-verify paid access.
- Interval-valid internal grants reject incoherent source/tier/date combinations.
- Granted capabilities are distinct from currently available capabilities.
- Authorization, platform, distribution, implementation, runtime, and policy failures accumulate.
- OS safety, enforced management, user choice, recommendations, and app defaults retain provenance;
  recommendations may opt out but never supply consent.
- Managed configuration and audit schemas are exhaustive and exclude personal coach cadence.
- Expiry may preserve only committed session-boundary capabilities when evidence, receipt, lease,
  limits, complete environment, and policy contexts match exactly.
- Claim loss, logout/verifier fallback, mismatched evidence, and changed contexts fail immediately to
  the new available-capability set.

## Canonical trace repair

The prior scratch trace review found that Atom 2.2 must not claim future publication or data-layer
proof. The canonical artifacts now:

- add `G-007` and assign independent capability-only publication to Atom 5.2;
- assign expiry-only lease boundary integration and runtime fallback proof for `G-004`/`G-005` to
  Atom 5.2, keeping the session engine capability-agnostic;
- assign Lite-after-Pro data readability/exportability proof for `G-004` to Atom 6.3;
- define independent session and capability streams through `CapabilitySnapshotSource`;
- use `.iCloudSync` rather than the obsolete `.historySync` example; and
- enumerate authorization, platform, distribution, implementation, runtime, and policy dimensions.

At the Atom 2.2 milestone, strict OpenSpec validation passed with 68 requirements and 117 scenarios.
The later pre-Atom-3.1 semantic-contract change adds stable trace scenarios; its current count is
tracked separately and does not retroactively enlarge Atom 2.2 proof. `SPEC.md` contains 57 EARS
acceptance criteria plus 12 separately documented assumptions, matching `prd.json`; the PRD records
21 atoms, 4 done, 17 todo, and Atom 3.1 as next.

## Independent review and council

- Implementation/API/security review: `READY`, zero Critical, Major, or Minor findings.
- Canonical trace review: initially `NEEDS_CHANGES` for one Major omission in the normative
  capability-allowed scenario. The scenario now explicitly requires adapter implementation,
  current runtime service/model availability, authorization, platform, distribution, and applicable
  policy. Fresh strict validation and 13/13 focused tests passed; re-review returned `READY` with
  zero remaining findings.
- Quick shipping council: three live seats completed the restatement gate, blind Round 1, and
  anonymized anti-conformity Round 2. All independently retained `ACCEPT_CONDITIONALLY`.
- Independent non-panel Chairman: `ACCEPT_CONDITIONALLY`; the staged index, receipt identities,
  exact metadata, and transaction gates were then verified before the milestone commit.

## Verification

- Focused Swift Testing: 13 tests in `EntitlementSnapshotTests`, all passed.
- Full package: 20 tests in 2 suites, all passed.
- Project generation/format: `PROJECT_GENERATION_OK` for Xcode 26.6, Swift 6.3.3, XcodeGen 2.46.0,
  and swift-format 6.3.0.
- Unsigned warnings-as-errors macOS build: `** BUILD SUCCEEDED **`.
- Release package build passed.
- Public symbol graph excludes internal grant, commit, lease, and validated-testing symbols.
- Signed app/UI regression: 3/3 passed; normalized receipt is
  `.agent/evidence/atom-2.2-app-test-receipt.json`; source result bundle is
  `.build/TestResults/Praxodoro-20260721T120251Z-75165.xcresult`.
- Isolated smoke passed with termination 143 and fatal-clean log
  `.build/Smoke/scaffold-20260721T120315Z-77483.log`.
- `gitleaks dir . --no-banner --redact` exited 0.
- Production package sources contain no StoreKit/CloudKit import, `UserDefaults`, `@AppStorage`, or
  `URLSession` dependency.
- Strict OpenSpec validation, JSON parsing, and `git diff --check` pass.

## Deliberate boundary

No StoreKit verifier, Enterprise license verifier, network service, mutable developer override,
capability publication source, or data read/export implementation is introduced in this atom.
Those surfaces remain owned by their later OpenSpec atoms.
