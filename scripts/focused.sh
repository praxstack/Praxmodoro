#!/usr/bin/env bash
# Per-atom focused check: the app unit suite only.
#
# This is the fast inner loop. It deliberately skips the UI-test target, the
# SwiftPM package suites, and the format lint — scripts/verify-project.sh is
# the gate that runs all of those. Regenerating first keeps the project in
# step with app/project.yml without the staleness diff that the gate applies.
set -euo pipefail
cd "$(dirname "$0")/.."

[ -d app/Praxmodoro.xcodeproj ] || ./scripts/generate.sh

xcodebuild \
  -project app/Praxmodoro.xcodeproj \
  -scheme Praxmodoro \
  -destination 'platform=macOS' \
  -only-testing:PraxmodoroTests \
  test | tail -3
