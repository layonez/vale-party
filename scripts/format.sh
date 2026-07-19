#!/usr/bin/env sh
set -eu
if command -v stylua >/dev/null 2>&1; then
  find . -name '*.lua' \
    -not -path './vendor/*' \
    -not -path './dist/*' \
    -not -path './node_modules/*' \
    -print0 | xargs -0 stylua
else
  echo "stylua not installed; format check skipped"
fi
