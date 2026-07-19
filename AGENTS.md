# Valya Adventure agent guide

Product goal: a tiny child-friendly LÖVE 11.4 MVP for desktop, browser via love.js, and a complete RG35XX Plus stock-firmware package.

Design & decision docs live in [`docs/`](docs/README.md): [globe & movement](docs/globe-and-movement.md), [world content & saving](docs/world-content.md), [Flight Map scene & mission loop](docs/flight-map.md), [testing & debug tooling](docs/testing-and-debug.md), and [stock-firmware packaging](docs/stock-firmware-packaging.md). The game spec is [`specs/flight_map_spec.md`](specs/flight_map_spec.md). Read these before changing the Flight Map; read the stock-firmware doc before touching `scripts/build-stock.sh` or `platform/stock/`.

Target device/resolution: Anbernic RG35XX Plus, fixed 640×480 logical canvas, 4:3 letterboxed scaling.

Child-friendly rules: no death, health, timers, scores, failure screens, negative sounds, flashing, rapid animation, tiny important text, or reading requirement before play. Use one primary action button, large zones, forgiving movement, and positive feedback.

Architecture boundaries: keep small modules under `src/core`, `src/platform`, `src/scenes`, `src/entities`, and `src/ui`. Platform-specific behavior belongs only in `src/platform` or `platform`. Do not add ECS, class framework, dependency injection, physics engine, large UI framework, native extensions, LuaJIT FFI, Phaser, TypeScript, Vite, Electron, or Chromium.

Controls: arrows/WASD move; Enter/Space interact/confirm; R/Backspace repeat/back; Escape/P pause; F1 debug. Controller uses SDL gamepad D-pad, A, B, Start through Baton.

Commands: `./scripts/run-desktop.sh`, `./scripts/test.sh`, `./scripts/lint.sh`, `./scripts/format.sh`, `./scripts/build-love.sh`, `./scripts/build-web.sh`, `./scripts/build-stock.sh`, `./scripts/check.sh`. Before committing, agents must run `./scripts/check.sh` and only commit if it passes. Install the versioned pre-commit hook with `./scripts/install-hooks.sh`; the hook runs `./scripts/check.sh`.

Add a localized string: add the same stable key to `content/localization/ru.lua` and `content/localization/de.lua`; Russian is the fallback.

Add an interactable: create a small explicit module or extend `src/entities/interactable.lua`, keep interaction range large, and trigger feedback through stable localization/audio IDs.

Definition of done for future activities: runnable without reading, localized, controller-ready through semantic actions, tested if pure logic changes, no unnecessary systems, documented stock assumptions if hardware is untested.
