# Web build

The browser build uses the same `dist/valya-adventure.love` package through love.js, not a JavaScript rewrite.

Run:

```sh
./scripts/build-web.sh
python3 -m http.server 8000 -d dist/web
```

Then open <http://localhost:8000>. Do not use `file://` because love.js needs browser fetch APIs.

Pinned love.js source: `Davidobot/love.js` `master` archive by default. Set `LOVEJS_ZIP` to a local compatible love.js release archive to avoid network downloads.
