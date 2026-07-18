#!/usr/bin/env sh
set -eu
mkdir -p dist
rm -f dist/valya-adventure.love
find . -type f \( -path './src/*' -o -path './content/*' -o -path './assets/*' -o -path './vendor/*' -o -name 'main.lua' -o -name 'conf.lua' -o -name 'LICENSE' \) | LC_ALL=C sort | zip -X -q dist/valya-adventure.love -@
echo dist/valya-adventure.love
