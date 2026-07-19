#!/usr/bin/env sh
set -eu

GAME_TITLE="Valya Adventure"
LOVEJS_VERSION="11.4.1"

./scripts/build-love.sh >/dev/null
rm -rf dist/web
mkdir -p dist/web

if [ -x ./node_modules/.bin/love.js ]; then
  LOVEJS="./node_modules/.bin/love.js"
else
  LOVEJS="npx --yes love.js@${LOVEJS_VERSION}"
fi

# Build the compatibility target so GitHub Pages can serve the game as plain
# static files without cross-origin isolation headers for SharedArrayBuffer.
$LOVEJS dist/valya-adventure.love dist/web -c -t "$GAME_TITLE"

cat > dist/web/README.md <<'EOT'
Serve this directory over HTTP. It contains the static love.js compatibility build generated from dist/valya-adventure.love and can be published directly by GitHub Pages.
EOT

echo "Created runnable love.js web build in dist/web."
