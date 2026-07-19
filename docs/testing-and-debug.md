# Testing & Debug Tooling

How this project is tested and driven, including the browser tooling built to
make the love.js web build observable.

## Pure logic is unit tested

Anything with real logic lives in a LÖVE-free module under `src/core/` and is
covered by [`tests/run.lua`](../tests/run.lua) (a plain Lua script, run with
`./scripts/test.sh` — no framework). Covered: sphere projection / pole
continuity / orthonormality, world lookups + `countryAt` + non-overlap,
recognition dwell/debounce, the full mission cycle (accept/cancel/complete/
reset), `screenDirection`, and savegame encode/decode/normalize + mission
snapshot/restore.

Rendering modules (`src/ui/*`, the scene's draw code) are **not** unit tested —
they are verified visually in the browser instead (see below). The split is
deliberate: keep decisions and math in testable pure modules, keep LÖVE calls in
thin draw layers.

## Driving the love.js build from the browser

love.js/SDL detects a keypress by diffing keyboard state **between frames**. A
synthetic `keydown`+`keyup` fired in the same tick collapses before the game
samples it, so scripted taps are missed. The fix, and the tooling built around
it:

- **`window.valya` command bridge** — [`platform/web/test-helpers.js`](../platform/web/test-helpers.js),
  injected into the web build by `scripts/build-web.sh`. It **holds** each key
  for ~150ms (several frames) before releasing, dispatched on `window` where
  SDL listens, so presses register reliably. Usage from the devtools console:
  `valya.press('a')`, `valya.hold('up', 600)`, `valya.sequence([...])`. Keys:
  `up down left right a b start debug drift reset finish`.
- **Console action logging** — `Input.logActions` prints `input:<action>` for
  every semantic press, and the scene logs `mission_accept` / `mission_complete`
  / `mission_cancel` / `recognized:<country>` / `cycle_celebration` /
  `cycle_reset`. This leaves a readable trail for both humans and automated
  browser checks (LÖVE's `print` routes to the browser console in love.js).

These are harmless in production — the bridge only adds console helpers and
never fires input on its own — so they ship in every build.

## Desktop screenshot harness

[`scripts/shot.lua`](../scripts/shot.lua) is a dev-only, **env-gated** harness
for capturing a single Flight Map frame from the desktop LÖVE build (verifying
sprites, HUD, highlights without a browser). `main.lua` loads it only when
`VALE_SHOT` is set, so normal runs are untouched, and it is never bundled (the
`.love` build globs `src/ content/ assets/ vendor/` + root files, not
`scripts/`). It boots straight into the Flight Map, lets ~30 frames settle,
writes `vale_shot.png` to the save dir, and quits. Optional overrides:

- `VALE_SHOT_HOVER="lat,lon"` — park the plane over a point (e.g. to show the
  hover highlight).
- `VALE_SHOT_MISSION="character_3"` — reset the cycle and accept that mission,
  to capture the active mission box.
- `VALE_SHOT_COUNTRY="Индия"` — force the recognised-country label (re-applied
  each frame, since `update` clears it when not dwelling).

Because LÖVE's `require` uses a virtual filesystem, the harness runs against the
real game root rather than a mounted subdir; gate it behind the env var instead.

## Keep the love.js data package small

love.js copies the whole packed `game.data` into the WASM heap in one
`HEAPU8.set`. Oversized assets overflow it and the web build dies at load with
`RangeError: offset is out of bounds` (in `processPackageData`) — the **desktop**
build is unaffected, so this only shows up in the browser. This bit us when
1024² character portraits pushed `game.data` past ~10MB; downscaling the sprites
to 256² (ample for their ~64px on-screen size) dropped it back to ~3MB and fixed
it. Keep source art sized for its on-screen use, and watch that stray files
(e.g. a `plane_old.png` backup left in `assets/`) don't get swept into the
build.

The same discipline applies to audio. Voice lines (`assets/voice/<lang>/*.ogg`)
and the looping music (`assets/music.ogg`) ship as **Vorbis `.ogg`**, converted
from mp3 masters that live in the **gitignored `voice-src/`** — masters never
enter `assets/`, so the build globs only the shipped `.ogg`s. Convert with:

```sh
ffmpeg -i voice-src/<name>.mp3 -ac 2 -c:a vorbis -strict -2 -q:a 4 assets/voice/ru/<id>.ogg
```

`-ac 2` and `-strict -2` are both required: Homebrew's ffmpeg ships without
`libvorbis`, so it uses the built-in experimental Vorbis encoder (`-strict -2`),
which only accepts stereo (`-ac 2`) — mono input fails with "only supports 2
channels".

## Debug keys (gated behind debug mode)

Toggle debug with **`` ` ``** (backtick — browser-safe, unlike F1 which the
browser intercepts). While debug is on:

- **`0`** — cycle auto-drift (globe rotates on its own; lets rotation show in a
  single screenshot without holding a key).
- **`9`** — reset the airplane to the start position.
- **`8`** — complete all missions at once, triggering the cycle celebration, so
  the finale is testable without flying all five.

The debug overlay (also toggled by backtick) shows lat/lon, the country under
the plane, the near character, and the mission state.

## Commit checks

`./scripts/check.sh` runs format → tests → lint → all three builds, and is the
pre-commit gate. It fails if formatting changed any tracked file, so stage work
(including formatting) before committing.
