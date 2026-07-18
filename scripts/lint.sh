#!/usr/bin/env sh
set -eu
if command -v luacheck >/dev/null 2>&1; then luacheck .; else echo "luacheck not installed; running syntax checks"; find . -name '*.lua' -not -path './vendor/*' -not -path './dist/*' -print0 | xargs -0 -n1 luac -p; fi
