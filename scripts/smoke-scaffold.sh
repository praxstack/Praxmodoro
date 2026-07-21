#!/usr/bin/env bash
set -euo pipefail

smoke_project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$smoke_project_root"

smoke_binary="$smoke_project_root/.build/DerivedData/Build/Products/Debug/Praxodoro.app/Contents/MacOS/Praxodoro"
[[ -x "$smoke_binary" ]] || {
  echo "ERROR: missing built app binary: $smoke_binary" >&2
  exit 1
}

/bin/mkdir -p .build/Smoke
smoke_state="$(/usr/bin/mktemp -d "$smoke_project_root/.build/Smoke/state.XXXXXX")"
smoke_log="$smoke_project_root/.build/Smoke/scaffold-$(date -u +%Y%m%dT%H%M%SZ)-$$.log"
smoke_pid=""

cleanup_smoke() {
  if [[ -n "$smoke_pid" ]] && /bin/kill -0 "$smoke_pid" 2>/dev/null; then
    /bin/kill -TERM "$smoke_pid" 2>/dev/null || true
  fi
  case "$smoke_state" in
    "$smoke_project_root"/.build/Smoke/state.*) /bin/rm -rf -- "$smoke_state" ;;
    *) echo "ERROR: refusing unexpected smoke cleanup path" >&2 ;;
  esac
}
trap cleanup_smoke EXIT

/bin/mkdir -p "$smoke_state/home" "$smoke_state/tmp" "$smoke_state/data"
CFFIXED_USER_HOME="$smoke_state/home" \
TMPDIR="$smoke_state/tmp" \
PRAXODORO_STATE_ROOT="$smoke_state/data" \
  "$smoke_binary" -PraxodoroSmokeMode YES >"$smoke_log" 2>&1 &
smoke_pid=$!

/bin/sleep 5
if ! /bin/kill -0 "$smoke_pid" 2>/dev/null; then
  echo "ERROR: Praxodoro exited before the smoke probe completed" >&2
  exit 1
fi

/bin/kill -TERM "$smoke_pid"
set +e
wait "$smoke_pid"
smoke_status=$?
set -e
smoke_pid=""

if [[ "$smoke_status" -ne 0 && "$smoke_status" -ne 143 ]]; then
  echo "ERROR: unexpected Praxodoro termination status: $smoke_status" >&2
  exit 1
fi

if /usr/bin/grep -Eiq 'fatal error|uncaught exception|crash' "$smoke_log"; then
  echo "ERROR: fatal marker found in smoke log: $smoke_log" >&2
  exit 1
fi

echo "SCAFFOLD_SMOKE_OK log=$smoke_log termination=$smoke_status"
