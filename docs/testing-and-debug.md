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
