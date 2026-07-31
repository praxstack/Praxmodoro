#!/usr/bin/env bash
set -euo pipefail

bootstrap_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$bootstrap_root"

expected_version="$(tr -d '[:space:]' < .xcodegen-version)"
expected_sha256="4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806"
expected_binary_sha256="8774da746668bc18fe74e54cbaf10f2631a1fb05947cd374179aa912f14f99db"
archive_url="https://github.com/yonaskolb/XcodeGen/releases/download/2.46.0/xcodegen.zip"
tool_parent="$bootstrap_root/.build/tools/xcodegen"
tool_root="$tool_parent/$expected_version"
binary="$tool_root/xcodegen/bin/xcodegen"

verify_binary() {
  local actual_binary_sha256
  actual_binary_sha256="$(/usr/bin/shasum -a 256 "$binary" | /usr/bin/awk '{print $1}')"
  if [[ "$actual_binary_sha256" != "$expected_binary_sha256" ]]; then
    echo "ERROR: XcodeGen executable checksum mismatch" >&2
    exit 1
  fi

  local version_output
  version_output="$("$binary" --version)"
  if [[ "$version_output" != "Version: $expected_version" ]]; then
    echo "ERROR: expected XcodeGen $expected_version, got: $version_output" >&2
    exit 1
  fi
}

if [[ -x "$binary" ]]; then
  verify_binary
  printf '%s\n' "$binary"
  exit 0
fi

if [[ -e "$tool_root" ]]; then
  echo "ERROR: partial XcodeGen tool directory exists: $tool_root" >&2
  exit 1
fi

/bin/mkdir -p "$tool_parent"
download_root="$(/usr/bin/mktemp -d "$tool_parent/.download.XXXXXX")"
archive="$download_root/xcodegen.zip"
unpacked="$download_root/unpacked"

cleanup_download() {
  case "$download_root" in
    "$tool_parent"/.download.*) /bin/rm -rf -- "$download_root" ;;
    *) echo "ERROR: refusing unexpected XcodeGen cleanup path: $download_root" >&2 ;;
  esac
}
trap cleanup_download EXIT

/usr/bin/curl --fail --location --silent --show-error "$archive_url" --output "$archive"
actual_sha256="$(/usr/bin/shasum -a 256 "$archive" | /usr/bin/awk '{print $1}')"
if [[ "$actual_sha256" != "$expected_sha256" ]]; then
  echo "ERROR: XcodeGen archive checksum mismatch" >&2
  exit 1
fi

/usr/bin/ditto -x -k "$archive" "$unpacked"
if [[ ! -x "$unpacked/xcodegen/bin/xcodegen" ]]; then
  echo "ERROR: official XcodeGen archive has the wrong layout" >&2
  exit 1
fi

/bin/mv "$unpacked" "$tool_root"
verify_binary
printf '%s\n' "$binary"
