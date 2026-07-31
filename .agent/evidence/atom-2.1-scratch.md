# Atom 2.1 scratch evidence

## Verdict

**PACKAGE BEHAVIOR VERIFIED; APP/UI REGRESSION BLOCKED BY LOCKED MAC.** The safe Lite inventory and
optional capability catalog are implemented exactly in the isolated scratch worktree. All focused
and full package tests pass, and all requested safe non-UI regressions pass. The complete atom is
not fully verified because the unchanged signed app/UI test driver was intentionally not run while
the Mac was locked.

Worktree:
`/Users/prax/Development/Praxodoro/.worktrees/atom-1-2-scratch`

## RED handed off by root

The root agent created
`Packages/PraxodoroCore/Tests/PraxodoroCoreTests/ProductRulesTests.swift` exactly from Task 1
Step 1 and ran:

```bash
swift test --package-path Packages/PraxodoroCore --filter ProductRulesTests
```

- Root-observed exit status: `1`.
- Output named `ProductRulesTests` and the missing `RequiredLiteFeature`, `ProductCapability`,
  `CapabilityDescriptor`, and `ProductRules` symbols.
- This was the required compile-time missing-behavior RED, not a zero-selected-tests result.

## Implemented files

- `Packages/PraxodoroCore/Sources/PraxodoroCore/Entitlements/ProductCapability.swift`
- `Packages/PraxodoroCore/Sources/PraxodoroCore/Entitlements/ProductRules.swift`

The root-authored `ProductRulesTests.swift` was preserved behaviorally and formatted only through
the planned package formatter command.

## Product invariants

- `RequiredLiteFeature` has an exhaustive inventory separate from all optional paid capabilities.
- `ProductRules.requiredLiteFeatures` is derived from every `RequiredLiteFeature.allCases` value;
  it has no entitlement or tier gate.
- `ProductRules.eligibleCapabilities(for: .lite)` is empty because this function concerns only the
  optional catalog; it does not remove or gate required Lite features.
- Every optional `ProductCapability` has one explicit `CapabilityDescriptor` containing minimum
  tier, authorization, platform eligibility, distribution, data access, downgrade behavior, and
  implementation status.
- There is no fallback descriptor and no `default` switch branch.
- `blockerExtension` is absent from production capability cases and descriptors.

## Formatting

```bash
xcrun swift-format format --configuration .swift-format --recursive --in-place \
  Packages/PraxodoroCore/Sources Packages/PraxodoroCore/Tests
```

- Exit status: `0`
- Scope stayed within planned package sources/tests and did not traverse SwiftPM `.build` output.

## Focused GREEN

```bash
swift test --package-path Packages/PraxodoroCore --filter ProductRulesTests
```

- Exit status: `0`
- Exact Swift Testing count: `6 tests` in `1 suite`, all passed, zero failures.
- Executed tests:
  - `requiredLiteInventoryIsExactAndUngateable()`
  - `everyOptionalCapabilityHasOneCompleteDescriptor()`
  - `editionEligibilityIsExact()`
  - `prerequisiteDimensionsRemainIndependent()`
  - `blockerIsNotImpliedByAnyTier()`
  - `enterpriseDataAccessIsConfigurationOnly()`
- The XCTest compatibility wrapper printed zero legacy XCTest tests before Swift Testing ran; that
  wrapper line is not being used as evidence.

## Full package GREEN

```bash
swift test --package-path Packages/PraxodoroCore
```

- Exit status: `0`
- Exact Swift Testing count: `7 tests` in `1 suite`, all passed, zero failures.
- Count composition: 6 `ProductRulesTests` plus
  `exposesStableProductIdentity()` from the scaffold suite.

## Deterministic catalog smoke

A Swift interpreter smoke compiled the exact two production entitlement source files and printed
the runtime registry values after the equality/completeness tests passed:

```text
REQUIRED_LITE_FEATURE_COUNT=29
OPTIONAL_DESCRIPTOR_COUNT=12
OPTIONAL_DESCRIPTOR_KEYS=advancedRecipes,appIntents,automatedExports,calendarIntegration,configurationAudit,enterpriseOfflineLicense,iCloudSync,managedDefaults,managedPrivacyPolicy,managedUpdates,onDeviceAI,richLocalAnalytics
BLOCKER_PRESENT=false
```

The exact-key test also proves
`Set(ProductRules.descriptors.keys) == Set(ProductCapability.allCases)`, so adding an enum case
without a descriptor fails the suite.

## Safe non-UI regressions

### Generation, toolchain, and format verifier

```bash
bash scripts/verify-project-generation.sh
```

- Exit status: `0`
- Output:
  `PROJECT_GENERATION_OK xcode=26.6 swift=6.3.3 xcodegen=2.46.0 swift-format=6.3.0`
- Recursive XcodeGen snapshot comparison and strict source lint both passed.

### Unsigned strict app build

```bash
xcodebuild \
  -project Praxodoro.xcodeproj \
  -scheme Praxodoro \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData \
  build CODE_SIGNING_ALLOWED=NO
```

- Exit status: `0`
- Result: `** BUILD SUCCEEDED **`
- Package and app Swift compiler invocations include `-warnings-as-errors` in Swift 6 mode.

### Scaffold verifier

```bash
bash scripts/verify-scaffold.sh
```

- Exit status: `0`
- Output: `SCAFFOLD_OK xcode=26.6 swift=6.3.3 xcodegen=2.46.0 targets=3`

### Isolated smoke

```bash
bash scripts/smoke-scaffold.sh
```

- Exit status: `0`
- Output:
  `SCAFFOLD_SMOKE_OK log=/Users/prax/Development/Praxodoro/.worktrees/atom-1-2-scratch/.build/Smoke/scaffold-20260720T162316Z-11374.log termination=143`
- The exact Debug app binary stayed live for the five-second isolated-home/tmp/state probe.
- Log size: `0` bytes. Fatal-marker grep exit status: `1`, so no marker matched.

### Strict OpenSpec

```bash
npm run spec:validate
```

- Exit status: `0`
- Result: `change/build-native-praxodoro` passed; totals `1 passed, 0 failed`.

### Diff and source review

```bash
git diff --check
rg -n '\bdefault\b|blockerExtension' \
  Packages/PraxodoroCore/Sources/PraxodoroCore/Entitlements
```

- `git diff --check` exit status: `0`.
- Production forbidden-symbol scan exit status: `1`, meaning no `default` fallback or
  `blockerExtension` match exists.

### Root and independent review

- Root independently confirmed all three source/test files are byte-identical to the accepted
  Task 1 plan, reran 6/6 focused tests and 7/7 full package tests, counted 29 Lite cases and 12
  optional cases from the production enums, and repeated generation, strict unsigned build,
  smoke, diff, and strict OpenSpec gates.
- A fresh 62.73 MB `gitleaks dir` scan completed with no leaks found.
- Independent caller-level review returned **PASS** with no Critical, Major, or Minor findings. It
  confirmed the Lite inventory has no tier/entitlement gate, all descriptors are explicit, value
  APIs are immutable and `Sendable`, and no default, fallback, blocker capability, privileged
  framework, completion-status mutation, UI run, or authentication mutation exists.
- Production checkpoint hashes: `ProductCapability.swift`
  `819a85059afbab35d80fad474da910c6c9a5e1466a891cbeaeec1a8136010632`, `ProductRules.swift`
  `1482ee17b2f4044b2a52c9a407ce5869783de4be2a899fa22b8277dd603e9695`, and
  `ProductRulesTests.swift`
  `f3d245775f8c8ec80bbd35bbb48f9e243fd168efc3faecc9cca1de579ae529e0`.

## Deliberately unrun verification

The following plan command was **not run**:

```bash
bash scripts/run-app-tests.sh
```

The Mac was locked, and the root explicitly prohibited running app/UI tests or touching
authentication/lock services. Therefore this atom has no fresh `.xcresult`, app-unit count, or UI
heading result. Package behavior is verified; complete cross-target regression remains blocked on
an unlocked Mac with clear system authentication.

## Scope and anomalies

- Xcode reported both arm64 and x86_64 destinations and selected arm64.
- Xcode's app metadata processor emitted the existing no-AppIntents-dependency warning; strict
  Swift/GCC source compilation still succeeded with warnings-as-errors.
- The scratch worktree already contained root-owned planning, atom 1.1/1.2, PRD, and progress
  changes. They were preserved.
- No OpenSpec checkbox, PRD/progress status, commit, auth/lock service, or file in
  `/Users/prax/Development/Praxodoro/.worktrees/native-app` was changed.

## Required completion step

After the Mac is unlocked and system authentication is clear, run the unchanged command:

```bash
bash scripts/run-app-tests.sh
```

Full atom verification requires the driver to emit `APP_TESTS_OK` with a retained Passed
`.xcresult`, zero failures, and named app-unit/UI evidence.
