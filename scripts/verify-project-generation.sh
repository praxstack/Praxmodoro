#!/usr/bin/env bash
set -euo pipefail

generation_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$generation_root"

[[ -f docs/engineering/dependencies.md ]] || {
  echo "ERROR: missing dependency provenance" >&2
  exit 1
}

xcode_version="$(xcodebuild -version | /usr/bin/sed -n '1s/^Xcode //p')"
swift_version="$(swift --version | /usr/bin/sed -n 's/.*Swift version \([^ ]*\).*/\1/p' | /usr/bin/head -1)"
format_version="$(xcrun swift-format --version)"
xcodegen_binary="$(bash scripts/bootstrap-xcodegen.sh)"
xcodegen_output="$("$xcodegen_binary" --version)"

[[ "$xcode_version" == "26.6" ]] || { echo "ERROR: Xcode $xcode_version" >&2; exit 1; }
[[ "$swift_version" == "6.3.3" ]] || { echo "ERROR: Swift $swift_version" >&2; exit 1; }
[[ "$format_version" == "6.3.0" ]] || { echo "ERROR: swift-format $format_version" >&2; exit 1; }
[[ "$xcodegen_output" == "Version: 2.46.0" ]] || {
  echo "ERROR: $xcodegen_output" >&2
  exit 1
}

/bin/mkdir -p .build
snapshot_root="$(/usr/bin/mktemp -d "$generation_root/.build/xcodegen-snapshot.XXXXXX")"
snapshot_project="$snapshot_root/Praxodoro.xcodeproj"
/usr/bin/ditto Praxodoro.xcodeproj "$snapshot_project"

cleanup_snapshot() {
  case "$snapshot_root" in
    "$generation_root"/.build/xcodegen-snapshot.*) /bin/rm -rf -- "$snapshot_root" ;;
    *) echo "ERROR: refusing unexpected snapshot cleanup path" >&2 ;;
  esac
}
trap cleanup_snapshot EXIT

"$xcodegen_binary" generate --spec project.yml
if ! /usr/bin/diff -qr "$snapshot_project" Praxodoro.xcodeproj; then
  echo "ERROR: XcodeGen output changed during no-diff regeneration" >&2
  exit 1
fi

xcrun swift-format lint --configuration .swift-format --strict \
  Packages/PraxodoroCore/Package.swift
xcrun swift-format lint --configuration .swift-format --recursive --strict \
  Packages/PraxodoroCore/Sources Packages/PraxodoroCore/Tests \
  PraxodoroApp PraxodoroTests PraxodoroUITests

echo "PROJECT_GENERATION_OK xcode=26.6 swift=6.3.3 xcodegen=2.46.0 swift-format=6.3.0"
