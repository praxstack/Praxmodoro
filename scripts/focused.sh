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

./scripts/generate.sh

# Explicit XXXXXX template: GNU mktemp rejects BSD's bare `-t prefix`.
log=$(mktemp "${TMPDIR:-/tmp}/praxmodoro-focused.XXXXXX")
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
  # Both diagnostic pipelines are best-effort and must never replace
  # xcodebuild's status: under pipefail + errexit, grep finding nothing
  # (a hung test runner logs no per-test line) exits 1, and head closing
  # the pipe after 40 lines makes the upstream exit 141 (SIGPIPE). Either
  # would abort here and skip the summary, the footer and `exit "$status"`.
  # scripts/test-focused.sh pins this with synthetic logs.
  #
  # Match compiler diagnostics, Swift Testing failures, xcodebuild's own
  # errors, and per-test failure lines. Deliberately anchored: the simulator
  # host logs lines containing "error:" (linkd/XPC chatter) that would
  # otherwise bury the real cause.
  grep -E '✘|\.swift:[0-9]+:[0-9]+: (error|warning):|^xcodebuild: error:|[Tt]est [Cc]ase .* failed' "$log" \
    | sort -u | head -40 || true
  # The "Testing failed:" summary names every failing test and crash even
  # when no per-line diagnostic matched above (two red CI runs printed
  # nothing actionable without it).
  sed -n '/^Testing failed:/,/^\*\* TEST FAILED \*\*/p' "$log" | head -40 || true
  echo "--- full log: rerun with the same command to reproduce ---"
  exit "$status"
fi
