# Praxmodoro setup (macOS, Xcode 27.0, verified 2026-10-04, HEAD 3531d6a)

Stack: Swift 6 / SwiftUI macOS 26 app, XcodeGen (`app/project.yml`), two local SwiftPM packages (PraxmodoroCore, PraxmodoroStore). No env vars, no network, no secrets needed.

## Commands (run from the repo root)
1. `./scripts/generate.sh`  (xcodegen; writes gitignored app/Praxmodoro.xcodeproj and Sources/Generated/BuildProvenance.swift) -> OK
2. `swift test --package-path app/Packages/PraxmodoroCore`  -> 49 tests / 13 suites pass
3. `swift test --package-path app/Packages/PraxmodoroStore` -> 8 tests / 6 suites pass
4. `swift format lint --strict --recursive app/Sources app/Packages/PraxmodoroCore/Sources app/Packages/PraxmodoroStore/Sources` -> clean (exit 0). No swiftlint config exists.
5. Build: `xcodebuild -project app/Praxmodoro.xcodeproj -scheme Praxmodoro -destination 'platform=macOS' -derivedDataPath <dir> build` -> BUILD SUCCEEDED (ad-hoc signed, warnings-as-errors on)
6. Run: `./scripts/run.sh`, or launch the built app: `<dir>/Build/Products/Debug/Praxmodoro.app/Contents/MacOS/Praxmodoro -praxmodoro-ephemeral-store` (in-memory store, touches no user data). Or `./scripts/smoke.sh`.
7. Full gate: `./scripts/verify-project.sh` (needs GUI session; UI tests need Accessibility/automation permission, not granted here).

## Smoke result
Built app launched with ephemeral store, signature verified, registered with the window server (lsappinfo), stayed alive 2s, then was killed. No leftover processes.

## Known failure / workaround
`xcodebuild ... test -only-testing:PraxmodoroTests` (the hosted app unit suite, ~345s) failed: "Praxmodoro encountered an error (The test runner hung before establishing connection)". Log: audit dir test.log. Cause not proven: the hosted test bundle is injected into the app, and in this non-interactive agent session the app logged linkd/autoShortcut connection errors; most likely the test runner cannot attach without a logged-in GUI session / testmanagerd access. Run it from the owner's Terminal in a normal desktop session (`./scripts/focused.sh`) to confirm. UI test suite (237 per README) not run (needs Accessibility permission; never granted).

## Env requirements
None. Tools: Xcode 26.6+ (27.0 works), xcodegen (`brew install xcodegen`); Node only for optional OpenSpec scripts (`npm run spec:validate`).
