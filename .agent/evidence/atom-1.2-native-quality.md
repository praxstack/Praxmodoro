# Atom 1.2 native project-quality evidence

## Candidate verdict

**GREEN / RE-REVIEW PENDING.** Deterministic project generation, formatting, strict concurrency,
warnings-as-errors, dependency provenance, signed app tests, and native smoke gates pass in the
ordered `feat/native-app` worktree. This record does not mark Atom 1.2 complete; independent
re-review, council acceptance, exact staged-scope audit, and the milestone commit remain required.

Candidate base: `514ebd8` (`chore: scaffold native macOS app`).

## RED provenance

Atom 1.2 began in an isolated scratch worktree before ordered integration was unblocked. The
unchanged initial verifier exited `1` with `ERROR: missing dependency provenance`; the durable RED
record is `progress.txt` line 53. Implementation was integrated here path-by-path after Atom 1.1
committed. Later scratch atoms were excluded.

## Integrated quality surface

- `.swift-format` pins explicit Swift formatting and lint policy.
- `docs/engineering/dependencies.md` records XcodeGen 2.46.0 source, tag commit, archive and
  executable checksums, license, tool-only scope, upgrade path, and removal path. The app still has
  no non-Apple runtime dependency.
- `project.yml` enables Swift 6 strict concurrency plus Swift and GCC warnings-as-errors; the
  generated project carries all three settings in Debug and Release.
- `scripts/verify-project-generation.sh` verifies Xcode 26.6, Swift 6.3.3, swift-format 6.3.0,
  checksum-verified XcodeGen 2.46.0, recursive no-diff regeneration, and scoped strict lint.
- `README.md` exposes the actual native bootstrap, verifier, package, build, signed-test, and smoke
  commands.
- `PraxodoroUITests/PraxodoroLaunchUITests.swift` isolates multi-display placement by moving the
  test cursor to the main display before launch and restoring its prior position during teardown.
  The accepted production `WindowGroup` and direct post-launch semantic-heading assertion remain
  unchanged; the test performs no menu command and creates no replacement window.

The six extracted scratch checkpoints remain byte-identical: `.swift-format`
`881a1584621cd34139192873801cbad4225303c563086a1b0068cf8f076a524d`, dependency record
`a14076aa0767b08edd6a1bdb7afbcdde358eb9c8cff875d611c68fa4019bcfbe`, verifier
`14259e6e60e636c2b5eb2937c7f4dae180834166754fbb7ee90c0211e69674c1`, `project.yml`
`eb3c221c174966f912b63081de3bd6d5ecd174bd653a3f41aed56380b3c1a6b2`, generated project
`ed50225a3cd5afc5b0a01e66114adfcb70be7d1ceec8352b7329f9258c080c89`, and README
`f1fb77bd8c835bd2d689cb4b33028e129e4da5ab04515278debabb81027a7b5e`.

## Fresh verification

- `bash scripts/verify-project-generation.sh`: exit `0`;
  `PROJECT_GENERATION_OK xcode=26.6 swift=6.3.3 xcodegen=2.46.0 swift-format=6.3.0`.
- `bash scripts/verify-scaffold.sh`: exit `0`;
  `SCAFFOLD_OK xcode=26.6 swift=6.3.3 xcodegen=2.46.0 targets=3`.
- `swift test --package-path Packages/PraxodoroCore`: exit `0`; named
  `exposesStableProductIdentity()` test passed.
- Unsigned Xcode build: exit `0`, `** BUILD SUCCEEDED **`; Swift compiler invocation contains
  `-warnings-as-errors`.
- `bash scripts/run-app-tests.sh`: two consecutive final executions exited `0` with
  `APP_TESTS_OK total=3 passed=3`. The retained second bundle is
  `.build/TestResults/Praxodoro-20260721T112037Z-30323.xcresult`; its normalized committed receipt
  is `.agent/evidence/atom-1.2-app-test-receipt.json`.
- `bash scripts/smoke-scaffold.sh`: exit `0`; the exact Debug app stayed live for five seconds with
  no fatal log marker and terminated deliberately with status `143`.
- `xcodebuild -list -json -project Praxodoro.xcodeproj`: app, app-unit, and UI-test targets plus the
  Praxodoro shared scheme are present.
- `npm run spec:validate`: strict OpenSpec result `1 passed, 0 failed`.
- `bash -n`, ShellCheck, and `git diff --check`: exit `0`.
- `gitleaks dir . --no-banner --redact --no-color`: scanned about 343.47 MB with no leaks found.

Ignored local transcripts for this run include `.build/atom-1.2-unsigned-build-final.log`,
`.build/atom-1.2-final-app-tests.log`, `.build/atom-1.2-final-app-tests-repeat.log`, and the two raw
JSON artifacts named by the normalized receipt.

## UI gate anomaly and strict remediation

Failed captures placed Praxodoro's persisted frame at x=1928 while the XCUITest accessibility
capture covered the 1920-pixel main display. The app exposed its menu and status item but no window
node in that capture. This was a multi-display test-environment failure; it did not justify changing
the production scene or accepting a weaker assertion.

An interim Command-N fallback was rejected because it could create a replacement window. A second
interim existing-window menu selection was also rejected by two reviewers because it could mask
initial presentation. Both were removed. The production `WindowGroup` is byte-identical to the
accepted Atom 1.1 implementation. The final test anchors launch to the main display, restores the
cursor, and then performs the original direct `initiate.heading` assertion. Two consecutive final
signed suites passed without any recovery branch.

## Commit kill criteria

Do not credit or commit Atom 1.2 if re-review finds a Critical, Major, or unresolved Minor issue; if
a fresh gate fails; if generated output changes; if the exact raw extraction commands and artifacts
do not reproduce the receipt hashes; if staged paths exceed the reviewed allowlist; or if
OpenSpec/PRD/progress claim success before all checks and council acceptance are complete.
