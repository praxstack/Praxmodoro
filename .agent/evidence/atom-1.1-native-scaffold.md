# Atom 1.1 native scaffold evidence

## Verdict

**VERIFIED — INDEPENDENTLY REVIEWED AND READY FOR COMMIT.** The scaffold, package test, deterministic
regeneration, unsigned app build, normal local-signing app/unit/UI suite, and isolated process
smoke all pass. The retained result bundle contains three executed tests with `result=Passed`,
including the real accessibility lookup in `testLaunchesInitiateSurface`. Earlier locked-Mac and
LocalAuthentication failures remain below as diagnostic history; no signing or UI-test criterion
was weakened to obtain the pass.

## Toolchain

- Xcode: `Xcode 26.6` (`Build version 17F113`)
- Swift: `Apple Swift version 6.3.3 (swiftlang-6.3.3.1.3 clang-2100.1.1.101)`
- XcodeGen: repo-local `Version: 2.46.0`
- XcodeGen archive expected SHA-256 verified before extraction:
  `4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806`
- XcodeGen extracted universal executable SHA-256 verified before every invocation:
  `8774da746668bc18fe74e54cbaf10f2631a1fb05947cd374179aa912f14f99db`

## RED

The only newly created paths before RED were `.xcodegen-version`,
`scripts/bootstrap-xcodegen.sh`, and `scripts/verify-scaffold.sh`; both scripts were executable.

```bash
bash scripts/verify-scaffold.sh
```

- Exit status: `1`
- Observed output: `ERROR: missing scaffold file: project.yml`
- Accepted configuration RED: yes. This was not a shell syntax error, tool-install failure, or
  zero-test result.

## Bootstrap and project generation

```bash
xcodegen_binary="$(bash scripts/bootstrap-xcodegen.sh)"
"$xcodegen_binary" --version
```

- Exit status: `0`
- Output: `Version: 2.46.0`
- Binary:
  `/Users/prax/Development/Praxodoro/.worktrees/native-app/.build/tools/xcodegen/2.46.0/xcodegen/bin/xcodegen`

```bash
xcodegen_binary="$(bash scripts/bootstrap-xcodegen.sh)"
"$xcodegen_binary" generate --spec project.yml
```

- Exit status: `0`
- Generated `Praxodoro.xcodeproj` with `Praxodoro`, `PraxodoroTests`, and
  `PraxodoroUITests`, plus the shared `Praxodoro` scheme.
- Regeneration proof: `project.pbxproj` SHA-256 was
  `e4321f4184068181c70f6b6cae755825f8cc697ed42ce2ecb3f48ee5526a7170` before and after a
  fresh generation.

### Bootstrap adversarial verification

An independent quality review found that the initial bootstrap authenticated the downloaded
archive but trusted an already cached executable if it merely printed the expected version. The
bootstrap now pins the extracted universal executable SHA-256 and checks it before every
invocation. Its exit trap also recursively removes only the exact repo-local `.download.*`
directory returned by `mktemp`, so interrupted extraction cannot leave nested residue.

- Valid cached executable: exit `0`; hash
  `8774da746668bc18fe74e54cbaf10f2631a1fb05947cd374179aa912f14f99db`;
  output `Version: 2.46.0`.
- Poisoned-cache fixture: `/usr/bin/true` was substituted in an ignored disposable bootstrap
  fixture; exit `1` with `ERROR: XcodeGen executable checksum mismatch`, proving rejection before
  invocation.
- Path-with-spaces fixture: exit `0` from an ignored root containing `bootstrap proof.*`; exact
  version output passed.
- Fresh-download fixture: exit `0`; extracted executable hash matched the pin; zero
  `.download.*` directories remained after the exit trap.
- The production cached binary was not modified by these tests.

## GREEN and final verification

### Scaffold verifier

```bash
bash scripts/verify-scaffold.sh
```

- Exit status: `0`
- Output:
  `SCAFFOLD_OK xcode=26.6 swift=6.3.3 xcodegen=2.46.0 targets=3`

### Strict Swift package test

```bash
swift test --package-path Packages/PraxodoroCore
```

- Exit status: `0`
- Named Swift Testing result:
  `exposesStableProductIdentity()` passed; `Test run with 1 test ... passed`.
- The command also prints the XCTest compatibility wrapper's `Executed 0 tests` line before the
  Swift Testing run. This is not being accepted as test evidence; the subsequent named Swift
  Testing test executed and passed.

### Unsigned app build

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

### Signed app-unit/UI test driver

```bash
bash scripts/run-app-tests.sh
```

- Final exit status: `0`.
- Output:
  `APP_TESTS_OK total=3 passed=3 result_bundle=/Users/prax/Development/Praxodoro/.worktrees/native-app/.build/TestResults/Praxodoro-20260721T102433Z-50191.xcresult`.
- Retained summary: `result=Passed`, `totalTestCount=3`, `passedTests=3`, `failedTests=0`,
  `skippedTests=0`, `expectedFailures=0` on arm64 macOS 26.5.2.
- Committed normalized receipt:
  `.agent/evidence/atom-1.1-app-test-receipt.json`; it records the raw extracted summary/tests
  JSON SHA-256 values without committing local device identity or the large ignored bundle.
- `applicationUsesCoreProductIdentity()` passed.
- `testStateRootOverrideIsConsumed()` passed.
- `testLaunchesInitiateSurface()` entered the XCUITest body, launched `com.praxodoro.app`, waited
  for the accessibility tree, found `"initiate.heading" StaticText`, and passed in 2.262 seconds.
- The normal local test-signing path used `Sign to Run Locally`; the driver contains no
  `CODE_SIGNING_ALLOWED=NO` test bypass.

The following failures are retained as historical diagnostics from before the Mac was unlocked;
they are not the final result:

- First exit status: `65`
- First retained bundle:
  `/Users/prax/Development/Praxodoro/.worktrees/native-app/.build/TestResults/Praxodoro-20260720T154155Z-59881.xcresult`
- First bundle summary: `totalTestCount=3`, `passedTests=2`, `failedTests=1`,
  `result=Failed`.
- `applicationUsesCoreProductIdentity()` passed.
- `testStateRootOverrideIsConsumed()` passed.
- `PraxodoroUITests-Runner` failed before entering the UI test body:
  `Authentication canceled. System authentication is running.`

The untouched exact driver was retried once:

```bash
bash scripts/run-app-tests.sh
```

- Retry exit status: `65`
- Retry retained bundle:
  `/Users/prax/Development/Praxodoro/.worktrees/native-app/.build/TestResults/Praxodoro-20260720T154335Z-60885.xcresult`
- Retry bundle summary: `totalTestCount=3`, `passedTests=2`, `failedTests=1`,
  `skippedTests=0`, `result=Failed`.
- Signed `build-for-testing` succeeded with `Sign to Run Locally`; this is not a code-signing
  failure.
- The two named app-unit tests passed again.
- The UI runner again failed to initialize with LocalAuthentication code `-4`, before
  `testLaunchesInitiateSurface` executed. At that time, the initiation heading had not yet been
  proven by XCUITest.

After the long-lived `LocalAuthentication.UIAgent` disappeared, the unchanged driver was retried
a third time. Signed `build-for-testing` succeeded and both named app-unit tests passed. The UI
runner reached `Running tests...` without the earlier code `-4`, but never entered
`testLaunchesInitiateSurface`; its app log reported that accessibility elements were below a
system `shield`. Read-only Computer Use inspection then reported: `The Mac is locked and automatic
unlock could not unlock it.` The exact test process was interrupted after 87 seconds rather than
left running indefinitely; the driver exited `73`, and its incomplete result bundle is retained at
`.build/TestResults/Praxodoro-20260720T160230Z-84158.xcresult`. This interrupted bundle is diagnostic
evidence only and is not counted as a test result.

### Isolated smoke

```bash
bash scripts/smoke-scaffold.sh
```

- Exit status: `0`
- Output:
  `SCAFFOLD_SMOKE_OK log=/Users/prax/Development/Praxodoro/.worktrees/native-app/.build/Smoke/scaffold-20260721T102611Z-55052.log termination=143`
- The exact Debug binary stayed live through the five-second probe with unique
  `CFFIXED_USER_HOME`, `TMPDIR`, and `PRAXODORO_STATE_ROOT` directories.
- Deterministic termination was SIGTERM status `143`.
- Smoke log size: `0` bytes. Fatal-marker grep returned `1`, meaning no
  `fatal error`, `uncaught exception`, or `crash` marker matched.
- This liveness smoke is independent evidence and does not substitute for the separately passed
  XCUITest heading assertion.

## Historical blocker diagnostics

- The failed `.xcresult` summaries independently record the UI runner initialization failure.
- Unified logs show `coreauthd` rejecting remote authentication ownership with the same code `-4`
  at `20:30:35`, `20:51:06`, `21:12:05`, and the retry at `21:13:38` local time.
- `testmanagerd` reports `Failed to enable Automation Mode` for the test session.
- During the first two attempts, `com.apple.LocalAuthentication.UIAgent` ran as PID `42554` and
  launchctl reported active LocalAuthentication UI/assertion endpoints. It was no longer present
  before the third attempt, but the Mac was then confirmed locked, which independently prevented
  UI automation from crossing the system accessibility shield.
- No Praxodoro, XCTRunner, or xcodebuild process remained after either failed test invocation.
- System authentication services were not killed or restarted because that would mutate unrelated
  user/system state. No `CODE_SIGNING_ALLOWED=NO` override was added to the test driver.

## Anomalies and review checks

- Xcode reports both arm64 and x86_64 macOS destinations and selects the first; all observed work
  ran on arm64.
- Xcode emits a metadata-extraction warning that no AppIntents dependency exists. This scaffold
  intentionally declares none; no Swift compiler source warning was observed.
- Historical app-unit launch logs contain `com.apple.linkd.autoShortcut` connection errors and an
  accessibility shield message while system authentication was active. The app-unit tests still
  executed and passed; that UI runner was blocked before its test body. The final unlocked run
  entered and passed the UI test as recorded above.
- All four shell scripts pass `bash -n` and are mode `0755`.
- `git diff --check` exits `0`.
- Scope review found atom 1.1 scaffold/generated/test paths; this evidence and compact receipt;
  checksum alignment in `BLUEPRINT.md`, the exact-code plan, and OpenSpec design/task text; plus
  PRD/progress workflow state. Scratch-atom progress entries are explicitly approved as durable,
  uncredited audit history. The Task 1.2 wording change only keeps its future provenance contract
  consistent with atom 1.1's reviewed executable pin; no Task 1.2 implementation is present.
- The fresh independent remediation review returned **PASS** with no Critical, Major, or Minor
  findings: executable identity is verified before execution; poisoned-cache, clean-download,
  path-with-spaces, guarded-cleanup, syntax, ShellCheck, plan parity, diff, and strict OpenSpec
  evidence all passed.

## Fresh closure gates on 2026-07-21

- XcodeGen generation against a recursive `/tmp` snapshot produced `GENERATION_NO_DIFF`.
- `xcodebuild ... build CODE_SIGNING_ALLOWED=NO` exited `0` with `** BUILD SUCCEEDED **`.
- Strict OpenSpec validation passed 1/1 with zero failures.
- `git diff --check` exited `0`.
- A fresh `gitleaks dir` scan covered 113.27 MB and found no leaks.
- The only refresh anomaly was an attempted call to atom 1.2's not-yet-integrated
  `scripts/verify-project-generation.sh`; it exited `127` after the preceding scaffold/package
  gates passed. The exact atom 1.1 plan was then reread, and its required generation/build/test/
  smoke gates were run directly and passed. No source or test was changed in response.

## Required next action

Commit the exact council-approved allowlist as `chore: scaffold native macOS app`, then rerun
recursive regeneration/no-diff and require every scoped atom/canonical/evidence path to be clean.
Any extra staged path, receipt mismatch, generated diff, or dirty scoped status invalidates the
completion transition before atom 1.2 begins.
