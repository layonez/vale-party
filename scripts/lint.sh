#!/usr/bin/env sh
set -eu
if command -v luacheck >/dev/null 2>&1; then luacheck . --exclude-files node_modules dist; else echo "luacheck not installed; running syntax checks"; find . -name '*.lua' -not -path './vendor/*' -not -path './dist/*' -not -path './node_modules/*' -print0 | xargs -0 -n1 luac -p; fi
