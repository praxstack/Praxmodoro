# Atom 1.2 scratch evidence

## Verdict

**PARTIAL / UI-BLOCKED.** Atom 1.2 is implemented in the isolated scratch worktree and every
requested safe non-UI gate passes. The complete atom is not verified because the required signed
app-unit/UI driver was intentionally not run while the Mac was locked. No test, signing setting,
authentication service, lock service, OpenSpec checkbox, PRD state, progress record, or commit was
changed by this pass.

Worktree:
`/Users/prax/Development/Praxodoro/.worktrees/atom-1-2-scratch`

## RED handed off by root

The root agent created `scripts/verify-project-generation.sh` exactly from Task 2 Step 1, made it
executable, and observed the required RED before this implementation pass:

```bash
bash scripts/verify-project-generation.sh
```

- Exit status: `1`
- Output: `ERROR: missing dependency provenance`
- This was the intended provenance-configuration RED, not a syntax or unrelated tool failure.

## Implemented scope

- Created `.swift-format` with the exact Task 2 formatting policy.
- Created `docs/engineering/dependencies.md` with XcodeGen tag, archive and executable checksums,
  license, scope, upgrade/removal path, Swift Format provenance, and no non-Apple runtime
  dependency claim.
- Added `SWIFT_STRICT_CONCURRENCY: complete`, `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES`, and
  `GCC_TREAT_WARNINGS_AS_ERRORS: YES` under top-level `settings.base` in `project.yml`.
- Replaced the stale pre-scaffold README sentence and appended the exact
  `Native foundation commands` section.
- Formatted only `Packages/PraxodoroCore/Package.swift`, the package source/test directories, and
  `PraxodoroApp`, `PraxodoroTests`, and `PraxodoroUITests`.
- Regenerated `Praxodoro.xcodeproj` with the repo-local checksum-verified XcodeGen.

## Toolchain

- Xcode: `26.6` (`Build version 17F113`)
- Swift: `6.3.3`
- swift-format: `6.3.0`
- XcodeGen: repo-local `Version: 2.46.0`
- XcodeGen archive SHA-256:
  `4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806`
- XcodeGen executable SHA-256:
  `8774da746668bc18fe74e54cbaf10f2631a1fb05947cd374179aa912f14f99db`

## Formatting and intentional generation

```bash
xcodegen_binary="$(bash scripts/bootstrap-xcodegen.sh)"
"$xcodegen_binary" generate --spec project.yml
git diff --check -- project.yml Praxodoro.xcodeproj
```

- Generation exit status: `0`
- Planned diff check exit status: `0`
- `project.pbxproj` changed from SHA-256
  `e4321f4184068181c70f6b6cae755825f8cc697ed42ce2ecb3f48ee5526a7170` to
  `ed50225a3cd5afc5b0a01e66114adfcb70be7d1ceec8352b7329f9258c080c89`.
- The generated delta contains all three strict settings in both Debug and Release project
  configurations.

```bash
xcrun swift-format format --configuration .swift-format --in-place \
  Packages/PraxodoroCore/Package.swift
xcrun swift-format format --configuration .swift-format --recursive --in-place \
  Packages/PraxodoroCore/Sources Packages/PraxodoroCore/Tests \
  PraxodoroApp PraxodoroTests PraxodoroUITests
```

- Manifest formatting exit status: `0`
- Recursive source formatting exit status: `0`
- SwiftPM `Packages/PraxodoroCore/.build` was not traversed.

## Verification results

### Project generation and lint

```bash
bash scripts/verify-project-generation.sh
```

- Exit status: `0`
- Output:
  `PROJECT_GENERATION_OK xcode=26.6 swift=6.3.3 xcodegen=2.46.0 swift-format=6.3.0`
- The verifier copied the complete pre-generation project, regenerated it, found no recursive
  difference, and linted only the planned manifest/source paths in strict mode.
- Snapshot cleanup completed; no `.build/xcodegen-snapshot.*` directory remained.

### Existing scaffold regression verifier

```bash
bash scripts/verify-scaffold.sh
```

- Exit status: `0`
- Output: `SCAFFOLD_OK xcode=26.6 swift=6.3.3 xcodegen=2.46.0 targets=3`

### Strict Swift package test

```bash
swift test --package-path Packages/PraxodoroCore
```

- Exit status: `0`
- Named Swift Testing evidence: `exposesStableProductIdentity()` passed and the Swift Testing
  summary reports one executed test.
- The preceding XCTest compatibility wrapper prints `Executed 0 tests`; that line is not being
  used as evidence.

### Strict unsigned app build

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
- The Swift compile invocation contains `-warnings-as-errors` and Swift language version 6.

### Isolated smoke

```bash
bash scripts/smoke-scaffold.sh
```

- Exit status: `0`
- Output:
  `SCAFFOLD_SMOKE_OK log=/Users/prax/Development/Praxodoro/.worktrees/atom-1-2-scratch/.build/Smoke/scaffold-20260720T161036Z-94753.log termination=143`
- The exact Debug binary remained live through the five-second isolated-home/tmp/state probe.
- Termination status: `143` after deterministic SIGTERM.
- Log size: `0` bytes. Fatal-marker grep exit status: `1`, meaning no marker matched.

### Generated target inventory

```bash
xcodebuild -list -json -project Praxodoro.xcodeproj
```

- Exit status: `0`
- Targets present: `Praxodoro`, `PraxodoroTests`, `PraxodoroUITests`.
- Shared scheme present: `Praxodoro`.

### Strict OpenSpec

```bash
npm run spec:validate
```

- Exit status: `0`
- Result: `change/build-native-praxodoro` passed; totals `1 passed, 0 failed`.

### Diff and shell review

```bash
git diff --check
bash -n scripts/verify-project-generation.sh
```

- Both exit statuses: `0`
- `scripts/verify-project-generation.sh` remains executable (`0755`).
- Post-verifier generated project SHA-256 remains
  `ed50225a3cd5afc5b0a01e66114adfcb70be7d1ceec8352b7329f9258c080c89`.

### Root adversarial and independent review

- The unchanged verifier passed from an ignored copied project whose root contained spaces
  (`.build/atom 1.2 path proof.*`) and left zero `xcodegen-snapshot.*` directories.
- A 47.69 MB `gitleaks dir` scan completed with no leaks found.
- Root comparison against the untouched atom 1.1 worktree found only the planned Task 2 surfaces,
  this task's executable-plan clarification, and this scratch evidence.
- Independent review initially found one Minor README contradiction: the old sentence said native
  commands would be added immediately before the new command section. The README and Task 2 plan
  now carry the same current-state replacement text; focused re-review returned **PASS** with no
  Critical, Major, or Minor findings beyond the documented UI blocker.
- Checkpoint hashes: `.swift-format`
  `881a1584621cd34139192873801cbad4225303c563086a1b0068cf8f076a524d`, dependency record
  `a14076aa0767b08edd6a1bdb7afbcdde358eb9c8cff875d611c68fa4019bcfbe`, verifier
  `14259e6e60e636c2b5eb2937c7f4dae180834166754fbb7ee90c0211e69674c1`, `project.yml`
  `eb3c221c174966f912b63081de3bd6d5ecd174bd653a3f41aed56380b3c1a6b2`, generated project
  `ed50225a3cd5afc5b0a01e66114adfcb70be7d1ceec8352b7329f9258c080c89`, and README
  `f1fb77bd8c835bd2d689cb4b33028e129e4da5ab04515278debabb81027a7b5e`.

## Deliberately unrun gate

The following required GREEN command was **not run**:

```bash
bash scripts/run-app-tests.sh
```

The Mac was locked, and the root agent explicitly prohibited running the UI driver or touching
authentication/lock services. Therefore there is no atom 1.2 `.xcresult`, no fresh app-unit count,
and no fresh `testLaunchesInitiateSurface` result. The non-UI successes above do not substitute for
that missing proof.

## Anomalies and scope findings

- Xcode reports arm64 and x86_64 Mac destinations and selects the first; the build ran on arm64.
- `appintentsmetadataprocessor` emits `Metadata extraction skipped. No AppIntents.framework
  dependency found.` This is a non-Swift metadata-tool warning for an app that declares no
  AppIntents dependency; the strict Swift/GCC compile still succeeds with warnings-as-errors.
- The scratch worktree already contained root-owned planning, atom 1.1, PRD, and progress changes.
  They were preserved. This pass changed only Task 2's planned formatter/provenance/project/README
  surface, formatted planned Swift paths, regenerated the project, and added this evidence file.
- No file in `/Users/prax/Development/Praxodoro/.worktrees/native-app` was edited.

## Required completion step

After the Mac is unlocked and system authentication is clear, run the unchanged command:

```bash
bash scripts/run-app-tests.sh
```

Atom 1.2 is fully verified only if that driver emits `APP_TESTS_OK` with a retained Passed
`.xcresult`, zero failures, and named app-unit/UI evidence.
