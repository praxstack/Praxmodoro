#!/usr/bin/env bash
# Verification gate for the app scaffold (spec: app-scaffold).
# Fails if the generated project is missing, stale relative to project.yml,
# or the build / headless package tests fail.
set -euo pipefail
cd "$(dirname "$0")/.."

[ -d app/Praxmodoro.xcodeproj ] || { echo "FAIL: app/Praxmodoro.xcodeproj missing — run scripts/generate.sh"; exit 1; }

before=$(find app/Praxmodoro.xcodeproj -name project.pbxproj -exec shasum {} \;)
(cd app && xcodegen generate --quiet)
after=$(find app/Praxmodoro.xcodeproj -name project.pbxproj -exec shasum {} \;)
[ "$before" = "$after" ] || { echo "FAIL: .xcodeproj was stale or hand-edited — regenerated from project.yml"; exit 1; }

swift test --package-path app/Packages/PraxmodoroCore
swift test --package-path app/Packages/PraxmodoroStore
xcodebuild -project app/Praxmodoro.xcodeproj -scheme Praxmodoro -destination 'platform=macOS' build | tail -3
echo "verify-project: OK"
