# Web build

The browser build uses the same `dist/valya-adventure.love` package through love.js, not a JavaScript rewrite.

Run:

```sh
npm ci
./scripts/build-web.sh
python3 -m http.server 8000 -d dist/web
```

Then open <http://localhost:8000>. Do not use `file://` because love.js needs browser fetch APIs.

`./scripts/build-web.sh` uses the love.js compatibility target so the generated `dist/web` directory is static-hosting friendly and does not require cross-origin isolation headers. Pushes merged to `main` are built and deployed to GitHub Pages by `.github/workflows/pages.yml`.

The love.js npm package is pinned in `package-lock.json`; run `npm ci` before building locally for the same packager version used by CI.
