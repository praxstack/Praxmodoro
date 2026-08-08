#!/usr/bin/env bash
# Changed-surface smoke: the built artifact actually launches and stays up.
#
# What this proves: the app bundle exists, its signature verifies, it launches
# against a hermetic in-memory store, it registers with the window server as a
# GUI application, and it survives long enough not to be a launch-time crash or
# a code-signing SIGKILL — the exact failure class that blocked M1's UI tests.
#
# What this does NOT prove: that a window is laid out correctly, or that any
# surface renders. That is the UI-test suite's job (scripts/verify-project.sh).
#
# No user data is touched: -praxmodoro-ephemeral-store selects an in-memory
# store, so the real Application Support store is never opened.
set -euo pipefail
cd "$(dirname "$0")/.."

[ -d app/Praxmodoro.xcodeproj ] || ./scripts/generate.sh

xcodebuild -project app/Praxmodoro.xcodeproj -scheme Praxmodoro -destination 'platform=macOS' build | tail -1
products=$(xcodebuild -project app/Praxmodoro.xcodeproj -scheme Praxmodoro -destination 'platform=macOS' -showBuildSettings 2>/dev/null | awk '/ BUILT_PRODUCTS_DIR/{print $3; exit}')
bundle="${products}/Praxmodoro.app"

[ -d "$bundle" ] || { echo "FAIL: app bundle missing at ${bundle}"; exit 1; }
codesign --verify --deep "$bundle" || { echo "FAIL: signature does not verify"; exit 1; }

# Clear any instance a previously-killed run left behind. Without this the
# leftover squats the bundle id and the next XCUITest launch dies with
# "Runningboard error 5 / Launchd job spawn failed" — diagnosed 2026-08-08.
pkill -x Praxmodoro 2>/dev/null || true
sleep 0.5

"${bundle}/Contents/MacOS/Praxmodoro" -praxmodoro-ephemeral-store &
pid=$!
cleanup() { kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; }
trap cleanup EXIT

# lsappinfo prints the application's serial number when it finds a registered
# GUI app and nothing at all when it does not, so non-empty output is the
# check. Matching a specific token inside that output would bind us to an
# undocumented format.
registered=""
for _ in $(seq 1 40); do
  sleep 0.25
  kill -0 "$pid" 2>/dev/null || { echo "FAIL: app exited during launch (pid ${pid})"; exit 1; }
  if [ -n "$(lsappinfo find "pid=${pid}" 2>/dev/null)" ]; then
    registered="yes"
    break
  fi
done

[ -n "$registered" ] || { echo "FAIL: app never registered with the window server within 10s"; exit 1; }

sleep 2
kill -0 "$pid" 2>/dev/null || { echo "FAIL: app died after registering"; exit 1; }

echo "smoke: launched, signed, registered, and alive (pid ${pid})"
