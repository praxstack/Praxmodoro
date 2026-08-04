#!/usr/bin/env bash
# Per-atom focused check: the app unit suite only.
#
# This is the fast inner loop. It deliberately skips the UI-test target, the
# SwiftPM package suites, and the format lint — scripts/verify-project.sh is
# the gate that runs all of those. Regenerating first keeps the project in
# step with app/project.yml without the staleness diff that the gate applies.
#
# The full xcodebuild log always goes to a file. On success we print the tail;
# on failure we print the compiler and test diagnostics, because a truncated
# tail on a red run tells you nothing actionable.
#
# No timeout wraps xcodebuild: the caller (CI job, agent turn) owns that bound,
# and a hand-rolled watchdog here would risk killing a slow-but-healthy build.
set -euo pipefail
cd "$(dirname "$0")/.."

[ -d app/Praxmodoro.xcodeproj ] || ./scripts/generate.sh

log=$(mktemp -t praxmodoro-focused)
trap 'rm -f "$log"' EXIT

if xcodebuild \
  -project app/Praxmodoro.xcodeproj \
  -scheme Praxmodoro \
  -destination 'platform=macOS' \
  -only-testing:PraxmodoroTests \
  test > "$log" 2>&1
then
  tail -3 "$log"
else
  status=$?
  echo "FAIL: focused suite failed (xcodebuild exit ${status}). Diagnostics:"
  grep -E 'error:|✘|Testing failed|failed after' "$log" | sort -u | head -40
  echo "--- full log: rerun with the same command to reproduce ---"
  exit "$status"
fi
