#!/usr/bin/env bash
# Self-test for scripts/focused.sh failure diagnostics.
#
# Runs a copy of focused.sh in a scratch tree with xcodebuild and
# generate.sh stubbed (and mktemp held to GNU's template rule), feeding it
# synthetic xcodebuild logs. Each case
# checks the two promises focused.sh makes on a red run: the diagnostics
# and footer always print, and the script exits with xcodebuild's own
# status. Needs no Xcode, no project, and touches nothing in the repo.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"

scratch=$(mktemp -d "${TMPDIR:-/tmp}/praxmodoro-focused-test.XXXXXX")
trap 'rm -rf "$scratch"' EXIT

mkdir -p "$scratch/repo/scripts" "$scratch/bin"
cp "$here/focused.sh" "$scratch/repo/scripts/focused.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$scratch/repo/scripts/generate.sh"
# The stub replays $FAKE_LOG as xcodebuild's output and exits $FAKE_STATUS.
cat > "$scratch/bin/xcodebuild" <<'EOF'
#!/usr/bin/env bash
cat "$FAKE_LOG"
exit "$FAKE_STATUS"
EOF
# GNU mktemp (Linux/cloud) rejects a template without trailing X's, while
# BSD mktemp on macOS accepts a bare `-t prefix`. This shim applies the
# stricter GNU rule on every platform, so a non-portable call fails here.
real_mktemp=$(command -v mktemp)
cat > "$scratch/bin/mktemp" <<EOF
#!/usr/bin/env bash
for arg in "\$@"; do
  case "\$arg" in
    -*) ;;
    *XXX) ;;
    *) echo "mktemp: too few X's in template '\$arg'" >&2; exit 1 ;;
  esac
done
exec "$real_mktemp" "\$@"
EOF
chmod +x "$scratch/repo/scripts/"*.sh "$scratch/bin/xcodebuild" "$scratch/bin/mktemp"

failures=0
fail() {
  echo "not ok - $1: $2"
  failures=$((failures + 1))
}

# run_case NAME STATUS: feeds $scratch/log.txt, captures output and exit code.
run_case() {
  set +e
  out=$(FAKE_LOG="$scratch/log.txt" FAKE_STATUS="$2" PATH="$scratch/bin:$PATH" \
    bash "$scratch/repo/scripts/focused.sh" 2>&1)
  code=$?
  set -e
}

expect_red() {
  local name=$1 status=$2
  run_case "$name" "$status"
  [ "$code" -eq "$status" ] || fail "$name" "exit $code, want xcodebuild's $status"
  grep -q '^--- full log: rerun' <<<"$out" || fail "$name" "footer missing"
  [ "$code" -eq "$status" ] && grep -q '^--- full log: rerun' <<<"$out" && echo "ok - $name"
  return 0
}

# 1. Hosted runner hung: no per-line diagnostic matches, only the summary.
#    This is the shape of every red CI run since 2026-09-14.
cat > "$scratch/log.txt" <<'EOF'
Testing started
Testing failed:
	Praxmodoro (12128) encountered an error (The test runner hung before establishing connection.)

** TEST FAILED **
EOF
expect_red "runner hung, summary only" 65
grep -q 'test runner hung before establishing connection' <<<"$out" \
  || fail "runner hung, summary only" "summary body not printed"

# 2. No diagnostic of any kind (truncated or crashed log).
printf 'Build settings from command line:\n' > "$scratch/log.txt"
expect_red "no diagnostics at all" 65

# 3. More than 40 matching lines: head closes the pipe early (SIGPIPE).
{
  for i in $(seq 1 5000); do
    echo "Test Case '-[PraxmodoroTests.T test$i]' failed (0.001 seconds)."
  done
  echo "Testing failed:"
  for i in $(seq 1 5000); do echo "	T.test$i() failed"; done
  echo "** TEST FAILED **"
} > "$scratch/log.txt"
expect_red "SIGPIPE from head -40" 65
lines=$(grep -c "^Test Case '" <<<"$out" || true)
[ "$lines" -le 40 ] || fail "SIGPIPE from head -40" "printed $lines per-test lines, want <= 40"

# 4. Per-test failures are named.
cat > "$scratch/log.txt" <<'EOF'
/x/app/Tests/PraxmodoroTests/SoundDirectorTests.swift:12:5: error: Expectation failed
Test Case '-[PraxmodoroTests.SoundDirectorTests testWake]' failed (0.010 seconds).
✘ Test testWake() recorded an issue
Testing failed:
	SoundDirectorTests.testWake() failed
** TEST FAILED **
EOF
expect_red "named failures" 65
grep -q "SoundDirectorTests testWake\]' failed" <<<"$out" || fail "named failures" "Test Case line missing"
grep -q 'SoundDirectorTests.swift:12:5: error:' <<<"$out" || fail "named failures" "compiler-style line missing"

# 5. A non-65 status passes through unchanged.
printf 'xcodebuild: error: Unable to find a destination\n' > "$scratch/log.txt"
expect_red "status passthrough" 70

# 6. Green run prints the tail and exits 0.
printf 'a\nb\nTest Suite passed\n** TEST SUCCEEDED **\n' > "$scratch/log.txt"
run_case "green" 0
if [ "$code" -eq 0 ] && grep -q 'TEST SUCCEEDED' <<<"$out"; then echo "ok - green"; else fail "green" "exit $code"; fi

if [ "$failures" -gt 0 ]; then
  echo "test-focused: $failures failure(s)"
  exit 1
fi
echo "test-focused: OK"
