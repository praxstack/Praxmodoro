# Foundation Plan Council Decision

## Verdict

`GO_WITH_REQUIRED_CHANGES` from all three independent reviewers. No critical defect requires a
product or architecture reset. Implementation remains blocked until the corrections below are
in the executable plan, strict validation passes, and a fresh reviewer accepts the revision.

## Reviewers

| Lens | Verdict | Major themes |
|---|---|---|
| Native architecture/toolchain | GO_WITH_REQUIRED_CHANGES | regeneration false red/green, uncompiled tests, smoke isolation, forged evidence, incomplete descriptors |
| Test/proof feasibility | GO_WITH_REQUIRED_CHANGES | app/UI tests never run, formatter recursion, pin/integrity gaps, criterion overclaim, weak REDs |
| ADHD/privacy/design/product | GO_WITH_REQUIRED_CHANGES | ungateable Lite core, future-service overbuild, closed managed policy, committed-policy-only downgrade |

## Accepted Required Corrections

1. Bootstrap the exact official XcodeGen 2.46.0 release into ignored repo-local tooling from
   its published archive and SHA-256; compare the parsed version exactly and remove undeclared
   `jq` from the verifier.
2. Verify Xcode 26.6, Swift 6.3.3, and Xcode-bundled `swift-format` 6.3.0 from actual output.
   Lint only manifest/source/test paths, never SwiftPM `.build` products.
3. Compile and execute package, app-unit, and UI tests. Keep unsigned app compilation separate
   from locally signed/ad-hoc test execution and retain an `.xcresult` with named test evidence.
4. Replace process-liveness narration with a deterministic smoke harness using unique
   `CFFIXED_USER_HOME`, `TMPDIR`, and app state roots; check fatal logs and use the UI test to
   assert the initiation accessibility heading.
5. Compare XcodeGen output to a pre-generation directory snapshot. Do not compare an
   intentionally changed Task 1.2 project against the Task 1.1 commit before accepting the
   generated delta; run a separate clean-Git check after commit.
6. Separate the exhaustive, ungateable `RequiredLiteFeature` inventory from optional paid
   capabilities. Optional capability descriptors must explicitly record edition eligibility,
   authorization, platform eligibility, distribution, downgrade, and data access with a
   completeness test and no silent default.
7. Keep future integrations cataloged but unavailable until both an adapter and independent
   prerequisites exist. Remove privileged blocking from the Pro/Enterprise tier catalog until
   its separate add-on specification exists.
8. Replace caller-controlled `isVerified` with untrusted claims plus internal validated grants.
   With no production verifier in this change, public production resolution remains Lite-only;
   debug/test grants are visibly development evidence and cannot verify production access.
9. Make entitlement snapshots contain grant/availability separation, status, evidence source,
   issue/expiry metadata, limits, missing reasons, policy provenance, and next reevaluation.
   Reject inconsistent source/tier/missing-expiry states.
10. Replace the generic policy resolver with a closed typed schema. Managed enforcement can
    disable diagnostics/sync but cannot enforce personal coach cadence; user choice overrides a
    cadence recommendation. Configuration/audit fields exclude task, capacity, check-in,
    history, and productivity data by construction and exact-case tests.
11. Preserve only session-bound capabilities explicitly committed at session start and only
    for descriptor policies that defer entitlement expiry. Apply OS-safety, authorization, and
    enforced privacy changes immediately; deny new paid operations after expiry.
12. Treat `prd.json` criterion arrays as supporting mappings, never premature acceptance.
    Remove clearly unrelated mappings and reserve full acceptance for final evidence mapping.
13. Add heading semantics and keep the scaffold layout explicitly disposable/adaptive.
    Reconcile Hallmark status as approved directional evidence, not pixel/runtime proof.

## Evidence Resolved During Council

- Official tag commit: `8445e778451c7e44237b90281bde622d764b0084`.
- Official `xcodegen.zip` SHA-256:
  `4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806`.
- The downloaded archive contains `xcodegen/bin/xcodegen`; its exact output is
  `Version: 2.46.0`.
- Apple `plutil` can parse the `xcodebuild -list -json` target array, so `jq` is unnecessary.
- The Xcode 26.6 PackageDescription API exposes `.treatAllWarnings(as: .error)` for Swift
  package targets.
- Swift Testing parameterized-test syntax was not the defect; semantic coverage was.

## Parked, Not Hidden

- App Sandbox and Hardened Runtime are distribution/security decisions for a later approved
  signing boundary; final local verification must still audit current entitlements honestly.
- Whether macOS XCUITest succeeds with unsigned code is empirical. The revised plan separates
  unsigned build proof from the normal local test-signing path and fails rather than skipping.
