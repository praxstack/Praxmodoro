#!/usr/bin/env bash
set -euo pipefail

scaffold_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$scaffold_root"

required_files=(
  .xcodegen-version
  project.yml
  Packages/PraxodoroCore/Package.swift
  PraxodoroApp/PraxodoroApp.swift
  PraxodoroApp/Platform/AppPaths.swift
  PraxodoroApp/Features/FocusLoop/InitiateView.swift
  PraxodoroTests/ScaffoldIntegrationTests.swift
  PraxodoroUITests/PraxodoroLaunchUITests.swift
  Praxodoro.xcodeproj/project.pbxproj
)

for required_file in "${required_files[@]}"; do
  if [[ ! -f "$required_file" ]]; then
    echo "ERROR: missing scaffold file: $required_file" >&2
    exit 1
  fi
done

xcode_version="$(xcodebuild -version | /usr/bin/sed -n '1s/^Xcode //p')"
[[ "$xcode_version" == "26.6" ]] || {
  echo "ERROR: expected Xcode 26.6, got: $xcode_version" >&2
  exit 1
}

swift_version="$(swift --version | /usr/bin/sed -n 's/.*Swift version \([^ ]*\).*/\1/p' | /usr/bin/head -1)"
[[ "$swift_version" == "6.3.3" ]] || {
  echo "ERROR: expected Swift 6.3.3, got: $swift_version" >&2
  exit 1
}

xcodegen_binary="$(bash scripts/bootstrap-xcodegen.sh)"
[[ "$("$xcodegen_binary" --version)" == "Version: 2.46.0" ]] || {
  echo "ERROR: XcodeGen exact-version proof failed" >&2
  exit 1
}

swift package describe --package-path Packages/PraxodoroCore >/dev/null

target_json="$(xcodebuild -list -json -project Praxodoro.xcodeproj)"
target_xml="$(printf '%s' "$target_json" | /usr/bin/plutil -extract project.targets xml1 -o - -)"
for target_name in Praxodoro PraxodoroTests PraxodoroUITests; do
  if ! /usr/bin/grep -Fq "<string>$target_name</string>" <<<"$target_xml"; then
    echo "ERROR: missing Xcode target: $target_name" >&2
    exit 1
  fi
done

echo "SCAFFOLD_OK xcode=26.6 swift=6.3.3 xcodegen=2.46.0 targets=3"
