#!/usr/bin/env bash
# Regenerate frames 02–06 from tools/gen-moments.mjs, reset the open to its base length,
# restore the un-injected index and stamp the crossfades again.
# (transitions.mjs inject is not idempotent, so it always starts from tools/index.base.html.)
set -euo pipefail
PROJ="$(cd "$(dirname "$0")/.." && pwd)"
TRANSITIONS="${TRANSITIONS:-$HOME/.claude/skills/product-launch-video/scripts/transitions.mjs}"
node "$PROJ/tools/gen-moments.mjs" "$PROJ" >/dev/null
sed -i -E \
  -e 's/(data-composition-id="01-open" data-width="1920" data-height="1080" data-duration=")[0-9.]+"/\16"/' \
  -e 's/(<div id="open-sky" class="clip" data-start="0" data-duration=")[0-9.]+"/\16"/' \
  "$PROJ/compositions/frames/01-open.html"
cp "$PROJ/tools/index.base.html" "$PROJ/index.html"
cd "$PROJ"
node "$TRANSITIONS" inject --storyboard ./STORYBOARD.md --hyperframes .
node "$TRANSITIONS" verify --storyboard ./STORYBOARD.md --index ./index.html
