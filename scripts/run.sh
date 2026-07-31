#!/usr/bin/env bash
# Build and launch Praxmodoro locally.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -d app/Praxmodoro.xcodeproj ] || ./scripts/generate.sh
xcodebuild -project app/Praxmodoro.xcodeproj -scheme Praxmodoro -destination 'platform=macOS' build | tail -1
products=$(xcodebuild -project app/Praxmodoro.xcodeproj -scheme Praxmodoro -destination 'platform=macOS' -showBuildSettings 2>/dev/null | awk '/ BUILT_PRODUCTS_DIR/{print $3; exit}')
open "${products}/Praxmodoro.app"
