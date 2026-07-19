# World Content & Saving

Where the game's countries, airports, characters, and missions come from, how
detection works, and what persists.

## Data-driven content

**Decision:** All gameplay content lives in [`content/world.lua`](../content/world.lua)
and is read through [`src/core/world.lua`](../src/core/world.lua), which indexes
everything by id. Scene logic never hard-codes an individual country or
character (spec §19).

Content shape:

- **Countries** (8) — lat/lon position, a great-circle **detection region**
  (center + angular radius in degrees), procedural flag stripe colors, and an
  `airport_id`. Flags are colors (not art assets) so they render without any
  PNGs; a `flag_asset` path is recorded for a future art swap.
- **Airports** (1 per country) — all `state = "locked"` in the MVP, with an
  unused `level_id` recorded so unlocking later needs no data reshape.
- **Characters** (exactly 5) — fixed positions, color, and the mission each
  gives.
- **Missions** (5) — link a character to a target country.

A test (`data integrity: five characters, and every reference resolves`)
enforces that every cross-reference resolves and there are exactly five
characters/missions.

## Detection regions are circles, and must not overlap

Country detection uses **great-circle angular distance** from the plane's
sub-point to each region center; you are "over" a country when that distance is
within the region radius (`World:countryAt`). Regions are circles because it is
the simplest shape that can be slightly larger than the drawn outline (spec §7)
and cheap to test.

Regions **must not overlap** — spec §7 requires it and `countryAt` returns the
first match. The test `country regions do not overlap` checks every pair, so
tuning a radius too large fails CI rather than silently causing ambiguous
detection.

## Recognition dwell + debounce

[`src/core/recognition.lua`](../src/core/recognition.lua) tracks how long the
plane has been over a country and fires "recognised" once past a dwell time, then
holds until you leave (no re-fire while inside; re-recognise on return) — spec §8.

The dwell default is **0.1s** (the spec suggested ~1s but explicitly allows
tuning during playtesting; 0.1s felt much better in play). It is a single
constant in that module.

## Airports currently hidden

Airport rendering is disabled (the `Airport.draw` call and its require are
commented out in the scene) because airports are locked with no behavior behind
them yet. The data and [`src/ui/airport.lua`](../src/ui/airport.lua) renderer
stay in place — re-enable the one call when landing/level logic arrives.

## Saving

**Decision:** Persist only the minimum to resume (spec §20): airplane position,
current-cycle completion, and the active mission. Serialization is pure and
tested in [`src/core/savegame.lua`](../src/core/savegame.lua); the
`love.filesystem` I/O is in `savegame_love.lua`, mirroring the existing
`settings` / `settings_love` split.

- Position is stored as the front **lat/lon**, not the full orientation matrix —
  restoring via `Sphere.orientationFor` is close enough and keeps the save file
  small and human-readable.
- Decoding **tolerates corruption**: bad latitude is clamped, non-string ids are
  dropped, malformed data falls back to a fresh save — a broken file never
  crashes the game.
- Saved on pause and on quit (hump forwards `love.quit` to the scene's `quit`).
  `MissionState:restore` ignores unknown or stale ids so an old save from
  different content can't wedge the cycle.
