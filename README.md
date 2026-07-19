# Valya Adventure MVP

A small child-friendly LÖVE 11.5 vertical slice for validating controls, readability, and architecture for preschool activities on desktop, browser through love.js, and an Anbernic RG35XX Plus stock-firmware package scaffold.

## Features

- Main menu with Russian default and German language selector.
- One fixed 640×480 garden scene rendered to a canvas and letterboxed.
- Large character with four-way movement, normalized diagonals, bounds, and obstacle collision.
- One flower interactable with large range, visual response, placeholder sound, and localized text.
- B/repeat instruction, pause overlay, restart, and main-menu return.
- F1 debug overlay with scene, language, input/device context, FPS, player position, and interaction state.

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

`./scripts/build-stock.sh` creates `dist/stock/Roms/APPS/Valya Adventure.sh` and `ValyaAdventure/` with `game.love`, runtime/libs/saves/logs placeholders. Stock-firmware runtime integration is a scaffold pending physical RG35XX Plus validation; see `platform/stock/README.md`.

## Architecture

The code is intentionally small: `src/app.lua` owns canvas scaling, settings, localization, input, audio, and scene setup. Scenes are explicit HUMP Gamestate modules. Pure logic for localization, settings, movement, and interaction is testable without opening a LÖVE window.

## Licenses and references

Project code is MIT. Vendored Baton is MIT. Vendored HUMP Gamestate/Timer is MIT. LuaCATS LÖVE definitions are referenced for editor setup but not vendored. love.js is pinned as an npm dev dependency for browser runtime generation but not committed as generated runtime files. No external art or copyrighted audio is included; placeholder graphics are LÖVE primitives and placeholder sound is generated at runtime.

Reference review notes: love2d-cursor-template informed the simple Lua tooling/build layout; Baton is the semantic input abstraction; HUMP supplied only Gamestate/Timer; LuaCATS informed annotation style; exdial/anbernic-apps informed `Roms/APPS`; PortMaster docs informed local runtime/libs/log/save conventions; love.js remains the intended browser runtime; Phaser and Antura were treated only as UX/reference material, not runtime/architecture sources.
