#!/usr/bin/env bash
# Regenerate the Xcode project from app/project.yml. The .xcodeproj is a build
# artifact — never hand-edit it; edit project.yml and re-run this.
set -euo pipefail
cd "$(dirname "$0")/../app"
xcodegen generate
