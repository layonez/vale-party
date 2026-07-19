# Flight Map Scene & Mission Loop

The main playable scene: [`src/scenes/flight_map.lua`](../src/scenes/flight_map.lua),
with the mission model in [`src/core/mission_state.lua`](../src/core/mission_state.lua).

## Entry point

The game boots to the existing main menu; **Start** and pause **Restart** go to
the Flight Map (the old garden scene was removed). The spec (§3) says start
directly on the map with no menu, but per the user's call we kept the menu and
just replaced garden's slot with the map.

The pause scene was generalized from `garden`-specific to any `scene` with a
`drawWorld` method, so it renders whatever scene is beneath it while paused.

## Game states

The high-level states from spec §18 are split across two places:

- `MissionState.state` tracks **FREE_FLIGHT** / **MISSION_ACTIVE** (the model).
- The scene owns the transient **CYCLE_CELEBRATION** (a `celebrationTime` timer)
  and **PAUSED** is the existing pause scene pushed on the stack.
- **MISSION_COMPLETION** (spec §18, "input briefly ignored") is currently
  instantaneous — the green check + feedback tone is the confirmation. A timed
  beat could be added later without touching the model.

## The mission cycle (`MissionState`)

All cycle logic is a pure, tested module so the scene just drives it:

- `accept(characterId)` — only in free flight; hides the other characters,
  activates the panel slot, enters MISSION_ACTIVE.
- `cancel()` — B button; back to free flight, **not** completed, all unfinished
  characters restored (spec §6).
- `complete()` — marks the character done (green check), clears the mission,
  returns to free flight.
- `allCompleted()` / `reset()` — drive the celebration and cycle restart.
- `visibleCharacters()` / `panelStates()` — what the scene renders: all
  uncompleted characters in free flight, and none during an active mission (the
  chosen character has "boarded"; the panel + target guidance carry it).

## A is the single interaction button

Per the child-friendly rules, **A** carries all interaction and its effect is
state-dependent (spec §6):

- Free flight + near a character → **accept** that mission.
- Mission active + over the target country → **complete** it.
- Anywhere else → nothing.

A is edge-triggered (`input:pressed`), so **holding A never re-triggers** (spec
§6). **B** cancels an active mission.

## Characters, hover feedback, and highlight

Characters render as portrait art ([`src/ui/character.lua`](../src/ui/character.lua))
with a tinted glow behind them so they read as interactive beacons. Art loads
lazily and is cached by path; a vector dot is the fallback when there is no
graphics context (tests) or the asset is missing.

When the plane moves within range of a character (the "near" one, see
[world content](world-content.md#character-interaction-range-is-angular-not-pixels)),
it is **highlighted**: a brighter, faster-pulsing layered halo (colored fill +
white rim) and a gentle scale pulse on the sprite, while the other characters
dim slightly for contrast. Entering the near-state also plays a soft, short
"here!" blip (`Audio.playHover`) — **edge-triggered** on the scene's
`nearCharacterId` so it fires once on arrival, not every frame while lingering.
Because a hover means the plane sits *on top of* the character, the plane sprite
covers the art; the halo around the plane is what communicates the highlight.

## HUD layout

Everything sits at the screen edges so it never covers the globe center:

- **Progress panel** — a vertical column of character slots down the **left**
  edge, centered vertically ([`src/ui/progress_panel.lua`](../src/ui/progress_panel.lua)).
  Each slot shows the portrait (dimmed + green check when completed, bright
  border when active).
- **Recognised-country name** — a centered strip near the **top** edge
  (learning aid, spec §8).
- **Mission box** — bottom-right (below).

## Guidance while a mission is active (spec §13, §14)

- **Mission box** (bottom-right): the carried character's portrait on the left,
  a "wants to go" prompt, then the target country name in **bold** with its flag
  to the right. Bold is faked (DejaVuSans has no bold face) by stamping the text
  with 1px offsets; the name **auto-shrinks** to fit one line so long names like
  "Германия" never wrap.
- **Target arrow**: a large high-contrast chevron at the globe rim pointing
  toward the target **while it is behind the horizon**; it disappears once any
  part of the target is on screen.
- **Target highlight**: the target country's region glows green when visible,
  and pulses strongest when the plane is over it (completion available).

Target visibility is computed from the region center plus its outline samples,
so a partial edge coming over the horizon counts.

## Voice hints (spec §8, §11)

The game is for a pre-reader, so the key moments are also spoken in Russian.
`Audio.playVoice(audio, lang, id[, quiet])` loads `assets/voice/<lang>/<id>.ogg`,
caches each source, and plays it on a single shared voice channel so lines never
talk over each other. A missing file falls back to the confirmation beep, unless
`quiet` is set (additive cues that shouldn't beep in languages without a
recording).

| Moment | Trigger | Voice id |
| --- | --- | --- |
| Start greeting | `FlightMap:enter` | `greeting` (quiet) |
| Country recognized | dwell recognition | `voice.<country_id>` |
| Friend accepted | A near a character | active mission id (`mission_1`…`mission_5`) |
| Friend delivered | A over the target | `success` (quiet) |
| All five done | fifth completion / debug finish | `celebration` (quiet) |

Recordings live under `assets/voice/ru/` as Vorbis `.ogg`. Because playback
always falls back to a beep (or silence), the game runs fully without any voice
files present — dropping in a `de/` set later needs no code change.

## Cycle celebration (spec §17)

Completing the fifth mission pauses flight and shows a gentle festive overlay
(dimmed scene, slow color bursts, five checks, a localized "well done" message —
no flashing, per the child-friendly rules). It auto-ends after ~4s or A skips it,
then `reset()` restores the same five characters/missions and free flight
resumes.

## Rendering order

`drawWorld` draws back-to-front: starfield → ocean disc → continents →
graticule → country outlines/highlights → characters → horizon rim → the plane
(pinned at center, see [globe & movement](globe-and-movement.md#plane-sprite--facing))
→ HUD (left-column progress panel, top country-name strip, bottom-right mission
box, target arrow, celebration). Airports would sit between outlines and
characters but are currently disabled.
