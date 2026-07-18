#!/usr/bin/env sh
set -eu
./scripts/build-love.sh >/dev/null
rm -rf dist/web
mkdir -p dist/web
cp platform/web/index.html dist/web/index.html
cp dist/valya-adventure.love dist/web/game.love
cat > dist/web/README.md <<'EOT'
Serve this directory over HTTP. This scaffold contains game.love and index.html. To produce game.data/game.js/love.wasm, install or provide a compatible love.js release and run its packager against game.love. Runtime is intentionally not vendored here.
EOT
echo "Created dist/web scaffold with game.love. Provide love.js runtime to complete wasm packaging."
