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

# conf.lua targets LOVE 11.4, matching love.js's bundled 11.4, so no version
# mismatch fires. Keep routing any "Compatibility Warning" message box to
# console.warn defensively so a future version bump can't reintroduce a blocking
# alert() on page load; all other message boxes (real errors) keep using alert().
node -e '
  var fs = require("fs");
  var f = "dist/web/love.js";
  var s = fs.readFileSync(f, "utf8");
  var from = "function($0,$1){alert(UTF8ToString($0)+\"\\n\\n\"+UTF8ToString($1))}";
  var to = "function($0,$1){var t=UTF8ToString($0),m=UTF8ToString($1);if(t.indexOf(\"Compatibility Warning\")!==-1){console.warn(t+\"\\n\"+m);return}alert(t+\"\\n\\n\"+m)}";
  if (s.indexOf(from) === -1) { console.error("build-web: compatibility-alert patch target not found in love.js"); process.exit(1); }
  fs.writeFileSync(f, s.split(from).join(to));
'

cat > dist/web/README.md <<'EOT'
Serve this directory over HTTP. It contains the static love.js compatibility build generated from dist/valya-adventure.love and can be published directly by GitHub Pages.
EOT

# Inject browser test helpers (window.valya console commands). Harmless in
# production — it only adds console helpers and never fires input on its own —
# so it ships with every build to keep the served page and the test page
# identical.
cp platform/web/test-helpers.js dist/web/test-helpers.js
node -e '
  var fs = require("fs");
  var f = "dist/web/index.html";
  var s = fs.readFileSync(f, "utf8");
  var tag = "<script src=\"test-helpers.js\"></script>";
  if (s.indexOf(tag) !== -1) process.exit(0);
  if (s.indexOf("</body>") === -1) { console.error("build-web: no </body> to inject test helpers"); process.exit(1); }
  fs.writeFileSync(f, s.replace("</body>", "    " + tag + "\n  </body>"));
'

echo "Created runnable love.js web build in dist/web."
