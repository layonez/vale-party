# Valya Adventure MVP

A small child-friendly LÖVE 11.4 vertical slice for validating controls, readability, and architecture for preschool activities on desktop, browser through love.js, and a complete Anbernic RG35XX Plus stock-firmware package.

## Features

- Main menu with Russian default and German language selector.
- Flight Map: a free-orientation textured Natural Earth globe rendered to a
  fixed 640×480 canvas and letterboxed.
- A plane with four-way movement over the globe, normalized diagonals, and
  gentle idle animation.
- Data-driven countries/airports/characters and a five-mission accept → guide →
  complete loop with positive feedback and localized text.
- Pause overlay, restart, and main-menu return.
- F1 debug overlay with scene, language, input/device context, FPS, position,
  and mission/recognition state.

## Commands

```sh
./scripts/run-desktop.sh
./scripts/test.sh
./scripts/lint.sh
./scripts/format.sh
./scripts/build-love.sh
./scripts/build-web.sh
./scripts/build-stock.sh
```

Linux: install LÖVE 11.5 and run `./scripts/run-desktop.sh`. macOS: install LÖVE 11.5, then run `love .` or the script if `love` is on PATH. Windows: install LÖVE 11.5 and run the project folder or `dist/valya-adventure.love` with love.exe.

## Builds

`./scripts/build-love.sh` creates deterministic `dist/valya-adventure.love` and excludes tests, logs, editor files, and VCS metadata.

`./scripts/build-web.sh` creates a runnable love.js compatibility build in `dist/web` with the same `.love` package. Run `npm ci` first for the pinned packager, then serve with `python3 -m http.server 8000 -d dist/web`. Do not use `file://`. Pushes merged to `main` are automatically built and deployed to GitHub Pages by `.github/workflows/pages.yml`.

`./scripts/build-stock.sh` creates a **complete, installable** Anbernic RG35XX Plus stock-firmware package under `dist/stock/Roms/APPS/` and a `dist/stock/valya-adventure-stock.zip`. It bundles a real aarch64 LÖVE 11.4 runtime plus every non-system shared library, so the game runs after a plain copy to the SD card with no manual runtime setup. Copy `dist/stock/Roms/APPS/` onto the card (TF1/TF2) or extract the ZIP at the card root, then launch from **App Center → Apps**. Runtime sources, versions, licenses, checksums, and installation/troubleshooting are in `platform/stock/README.md`; the engineering rationale (runtime choice, the launch bugs and fixes, on-device SSH debugging) is in [`docs/stock-firmware-packaging.md`](docs/stock-firmware-packaging.md).

## Architecture

The code is intentionally small: `src/app.lua` owns canvas scaling, settings, localization, input, audio, and scene setup. Scenes are explicit HUMP Gamestate modules. Pure logic for localization, settings, movement, and interaction is testable without opening a LÖVE window.

## Licenses and references

Project code is MIT. Vendored Baton is MIT. Vendored HUMP Gamestate/Timer is MIT. Vendored DejaVu Sans (`assets/fonts/DejaVuSans.ttf`) provides Latin and Cyrillic glyphs so Russian text renders correctly; it is redistributable under the Bitstream Vera / Arev license (see `assets/fonts/DejaVuSans-LICENSE.txt`). LuaCATS LÖVE definitions are referenced for editor setup but not vendored. love.js is pinned as an npm dev dependency for browser runtime generation but not committed as generated runtime files. Placeholder graphics are LÖVE primitives and the confirmation/hover beeps are generated at runtime. Bundled audio — Russian voice lines under `assets/voice/ru/` and looping music `assets/music.ogg` (both Vorbis, converted from mp3 masters kept locally in the gitignored `voice-src/`) — is original to this project. The stock-firmware package downloads and bundles a third-party aarch64 LÖVE 11.4 runtime (`Cebion/love2d_aarch64`, zlib) and supporting libraries from Ubuntu 22.04 `.deb` packages; each is pinned by checksum and its license is listed in `platform/stock/README.md`. These are fetched at build time, not committed.

Reference review notes: love2d-cursor-template informed the simple Lua tooling/build layout; Baton is the semantic input abstraction; HUMP supplied only Gamestate/Timer; LuaCATS informed annotation style; exdial/anbernic-apps informed `Roms/APPS`; PortMaster docs informed local runtime/libs/log/save conventions; love.js remains the intended browser runtime; Phaser and Antura were treated only as UX/reference material, not runtime/architecture sources.
