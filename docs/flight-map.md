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

## Guidance while a mission is active (spec §13, §14)

- **Mission box** (bottom-right): target flag, name, and a `?`.
- **Target arrow**: a large high-contrast chevron at the globe rim pointing
  toward the target **while it is behind the horizon**; it disappears once any
  part of the target is on screen.
- **Target highlight**: the target country's region glows green when visible,
  and pulses strongest when the plane is over it (completion available).

Target visibility is computed from the region center plus its outline samples,
so a partial edge coming over the horizon counts.

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
→ HUD (panel, mission box, arrow, name banner, celebration). Airports would sit
between outlines and characters but are currently disabled.
