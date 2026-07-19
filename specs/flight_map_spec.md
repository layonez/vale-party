# Flight Map MVP — Game Specification

## 1. Purpose

The Flight Map is the main playable scene and the initial entry point of the game.

The player controls a small airplane flying around a simplified rotating globe. The map supports:

* free exploration;
* discovering mission characters;
* accepting and completing simple delivery missions;
* learning the approximate location and names of selected countries;
* displaying airports that will later lead to country-specific levels.

In the first version, country levels are not implemented. Airports are visible but locked.

---

## 2. Target Platform

Primary target:

* Anbernic RG35XX Plus
* 640 × 480 display
* D-pad controls
* physical `A` and `B` buttons

The game must be fully playable without reading.

Text may be displayed as an additional learning aid, but all required actions must be understandable through visuals and simple interaction.

---

## 3. Initial Game State

The game starts directly on the Flight Map.

There is no separate main menu in the MVP.

Initial state:

* the airplane is positioned in the northern part of the globe;
* no mission is active;
* five mission characters are visible on the globe;
* the five-character progress panel is visible at the top of the screen;
* all airports are visible and locked.

The nearest meaningful object should be reachable after a short period of flying. The player should not start in a completely empty area.

---

## 4. Globe Presentation

The world is represented as a rotating sphere.

The camera shows a large, zoomed-in part of the globe rather than the complete planet.

Visual requirements:

* the planet surface fills most of the screen;
* the curvature of the planet is clearly visible;
* the horizon is visible near the edges;
* approximately two or three major geographical areas can normally be visible at once;
* distant terrain disappears naturally behind the horizon;
* there are no visible map borders or teleportation seams.

The airplane remains approximately in the center of the screen. Player movement is visually represented by rotating the globe beneath the airplane.

The airplane may rotate or tilt to show the current direction, but its screen position remains mostly fixed.

---

## 5. World Coordinates

The airplane, countries, airports, and mission characters are positioned using spherical world coordinates.

Each world position contains:

```yaml
latitude: number
longitude: number
```

The game must not depend on flat scrolling-map coordinates for world logic.

Longitude wraps continuously around the planet.

Movement across polar regions must remain continuous on the sphere.

---

## 6. Controls

### D-pad

The D-pad controls movement in four directions:

* `Up`
* `Down`
* `Left`
* `Right`

Movement rules:

* constant movement speed;
* no acceleration;
* no inertia;
* movement stops immediately when the direction is released;
* diagonal movement is not required;
* if conflicting directions are pressed, the implementation must choose one direction consistently.

### A button

The `A` button is the general interaction button.

It performs an action only when the airplane is inside a valid interaction area.

In the MVP, `A` can:

* accept a mission from a nearby mission character;
* complete the active mission while flying above the target country.

Pressing `A` elsewhere has no effect.

Holding `A` must not repeatedly trigger the same interaction.

### B button

If a mission is active, pressing `B` immediately cancels it.

After cancellation:

* the target direction arrow disappears;
* the target-country highlight disappears;
* the mission information box disappears;
* the mission is not marked as completed;
* all unfinished mission characters return to the globe.

If no mission is active, `B` has no required gameplay effect.

---

## 7. Playable Countries

The globe contains a limited number of highlighted playable countries.

The MVP should use approximately eight countries distributed across different parts of the world.

The selected countries do not need to form a strict geographical classification. They are recognisable travel destinations based on real-world geography.

Example candidates include:

* Germany
* Russia
* India
* China or Japan
* Brazil
* United States or Canada
* Australia
* one selected African country

The exact list is content configuration and can be changed without modifying the core Flight Map logic.

Country requirements:

* each country corresponds to a real country;
* it is placed in approximately the correct location;
* its visible shape may be simplified;
* its interactive detection area may be slightly larger than its visible outline;
* different country areas must not overlap logically.

Other parts of the world may appear as simplified background geography but do not need to be interactive.

---

## 8. Country Detection

The current country is determined using the world position directly beneath the center of the airplane.

When the airplane remains above a country for approximately one second:

* the country becomes recognised;
* its name is displayed;
* its name may be spoken;
* the country receives a subtle visual highlight.

The exact timing may be tuned during playtesting.

Country recognition should not repeatedly trigger while the airplane remains inside the same country.

After leaving and entering again, the country may be recognised again.

---

## 9. Airports

Each playable country contains one airport.

Airport requirements:

* always visible when its position is on the visible side of the globe;
* large enough to recognise on the small screen;
* placed inside its associated country;
* displayed consistently across all countries.

In the MVP, every airport is locked.

A locked airport displays a clear stop or unavailable symbol.

Locked airports:

* cannot be entered;
* do not start a landing animation;
* do not open another scene;
* do not react to `A`.

Airport data should already support a future transition to an unlocked state.

Example:

```yaml
airport:
  id: brazil_airport
  country_id: brazil
  position:
    latitude: 0
    longitude: 0
  state: locked
  level_id: brazil_level
```

`level_id` may be unused in the MVP.

---

## 10. Mission Characters

The current mission cycle contains exactly five predefined mission characters.

Mission characters:

* remain in fixed predefined positions;
* may appear on land, water, ice, islands, or visually in the air;
* have visible character icons;
* have a subtle animation or glow showing that they are interactive;
* each provide one fixed mission;
* always return to the same position in every cycle.

All five unfinished mission characters are visible during free flight.

No direction arrow points toward mission characters. The player discovers them while exploring.

---

## 11. Mission Character Interaction

When the airplane enters the interaction area of a mission character:

* the character highlight becomes stronger;
* pressing `A` immediately accepts the mission.

There is no separate confirmation screen.

After accepting a mission:

* the selected mission becomes active;
* the selected character is marked as active in the top progress panel;
* all other mission characters disappear from the globe;
* the mission target country becomes active;
* the mission target interface appears.

Only one mission can be active at a time.

---

## 12. Mission Content

Each mission contains at minimum:

```yaml
mission:
  id: string
  character_id: string
  target_country_id: string
```

Additional descriptive content, such as a delivered object, may be added later but is not required for the MVP gameplay loop.

Each of the five characters always provides the same predefined mission.

---

## 13. Target Direction Arrow

While a mission is active, the game helps the player locate the target country.

If the target country is not currently visible:

* a direction arrow appears at the edge of the screen;
* the arrow points toward the target country across the globe;
* it can rotate freely and is not limited to four directions;
* it updates continuously as the globe rotates;
* it points along the shortest practical route toward the target.

If two routes are nearly equivalent, the selected direction should remain stable and should not rapidly switch.

When a visible part of the target country appears on screen:

* the direction arrow disappears;
* the target country becomes visibly highlighted.

If the country goes behind the horizon again, the arrow returns.

---

## 14. Active Mission Box

While a mission is active, a small mission box is displayed in the bottom-right corner.

The box contains:

* the target country name;
* the target country flag;
* a question-mark symbol.

Example layout:

```text
┌─────────────┐
│ 🇧🇷          │
│ BRAZIL   ?  │
└─────────────┘
```

The box is hidden when:

* no mission is active;
* the mission is cancelled;
* the mission is completed.

The country name is supplementary. The player must still be able to follow the mission using the flag, arrow, and country highlight.

---

## 15. Completing a Mission

The player does not need to land at an airport in the MVP.

A mission can be completed anywhere above the visible territory of the target country.

Mission completion flow:

1. The target country is visible and highlighted.
2. The center point beneath the airplane enters the target-country area.
3. The country highlight becomes visibly stronger.
4. The player presses `A`.
5. The mission is marked as completed.

No separate `A` button prompt is displayed. The stronger country highlight is the only required visual indication that completion is available.

Pressing `A` above any other country does nothing.

After completion:

* the active mission is cleared;
* the mission box disappears;
* the target arrow disappears;
* the country highlight returns to normal;
* the associated character icon receives a green check mark;
* the remaining unfinished mission characters reappear;
* the game returns to free flight.

The exact completion animation and sound are outside the current specification.

---

## 16. Mission Progress Panel

A permanent progress panel is displayed at the top of the screen.

It contains five small boxes, one for each mission character.

Example:

```text
[Character 1] [Character 2] [Character 3] [Character 4] [Character 5]
```

Each slot has three states:

### Available

* normal character icon;
* mission is unfinished;
* character is available on the globe during free flight.

### Active

* character icon has an active highlight or border;
* this character’s mission is currently active.

### Completed

* a green check mark is displayed over the icon;
* the character no longer appears on the globe during the current cycle.

The panel remains visible while a mission is active, even though the other mission characters are hidden from the globe.

---

## 17. Mission Cycle

The MVP contains one fixed set of five missions.

The player may complete them in any order.

After all five missions are completed:

1. all five progress icons display green check marks;
2. airplane movement is temporarily paused;
3. a short celebration is shown;
4. the celebration can automatically end after a short duration;
5. pressing `A` may skip the celebration;
6. all completion states are reset;
7. the same five mission characters return to their original positions;
8. the same five missions become available again;
9. the game resumes in free-flight mode.

The following remain unchanged between cycles:

* mission characters;
* character positions;
* mission definitions;
* target countries;
* airports;
* airplane position.

No total cycle count or long-term mission history is required.

---

## 18. Game States

The Flight Map should support the following high-level states:

```text
FREE_FLIGHT
MISSION_ACTIVE
MISSION_COMPLETION
CYCLE_CELEBRATION
PAUSED
```

### FREE_FLIGHT

* no active mission;
* all unfinished mission characters are visible;
* no target arrow;
* no mission box.

### MISSION_ACTIVE

* one mission is active;
* non-selected characters are hidden;
* target arrow or target-country highlight is visible;
* `B` cancels the mission.

### MISSION_COMPLETION

* short transition after pressing `A` over the correct country;
* input may be temporarily ignored;
* mission status changes to completed.

### CYCLE_CELEBRATION

* entered after the fifth mission is completed;
* normal movement is paused;
* the mission cycle resets afterward.

### PAUSED

* world simulation and gameplay timers stop;
* gameplay input is ignored;
* resuming returns to the previous state.

A full pause menu is not required for the first implementation.

---

## 19. Data Configuration

Countries, airports, characters, and missions should be data-driven.

Example configuration:

```yaml
countries:
  - id: brazil
    display_name: Brazil
    flag_asset: flags/brazil.png
    voice_asset: voice/brazil.ogg
    region_shape: brazil_region
    airport_id: brazil_airport

airports:
  - id: brazil_airport
    country_id: brazil
    latitude: 0
    longitude: 0
    state: locked

characters:
  - id: character_1
    icon_asset: characters/character_1.png
    latitude: 0
    longitude: 0
    mission_id: mission_1

missions:
  - id: mission_1
    character_id: character_1
    target_country_id: brazil
```

The game logic must not contain hard-coded conditions for individual countries or characters.

---

## 20. Saving

The minimum required persistent state is:

* airplane position;
* current cycle completion state;
* active mission, if any.

If saving is omitted from the first technical prototype, restarting the game may reset the current cycle.

The implementation should avoid making future persistence difficult to add.

---

## 21. Out of Scope for the MVP

The following are explicitly outside the first version:

* playable country levels;
* airport landing;
* airport selection;
* multiple airplanes;
* speed upgrades;
* fuel;
* scores;
* timers;
* failure conditions;
* enemies;
* collision damage;
* inventory;
* random missions;
* random character positions;
* changing mission cycles;
* zoom controls;
* detailed dialogue;
* complex mission animations;
* localisation beyond initial configured text and voice assets.

---

## 22. Acceptance Criteria

The MVP is complete when:

1. The game opens directly on the rotating globe.
2. The airplane can move continuously around the spherical world using the D-pad.
3. The airplane remains approximately centered while the globe rotates beneath it.
4. Playable countries appear in approximately correct world locations.
5. Country detection uses the airplane’s central world position.
6. Country names can be shown when flying above them.
7. Five mission characters are visible in free flight.
8. The top panel displays the same five character icons.
9. Pressing `A` near a character immediately starts that character’s mission.
10. The other mission characters disappear while a mission is active.
11. The bottom-right mission box shows the target country name, flag, and question mark.
12. A direction arrow points toward a target country while it is behind the horizon.
13. The arrow disappears when the target country becomes visible.
14. The visible target country is highlighted.
15. The highlight becomes stronger when the airplane is above the target-country area.
16. Pressing `A` above the target country completes the mission.
17. Pressing `A` elsewhere does not complete it.
18. Pressing `B` cancels the active mission and restores unfinished characters.
19. Completed missions receive green check marks in the top panel.
20. Completed characters remain absent for the rest of the current cycle.
21. Airports are always visible and display a locked or stop icon.
22. Airports cannot be entered.
23. Completing all five missions triggers a short celebration.
24. After the celebration, the same five characters and missions reset in the same locations.
25. The cycle can be repeated without restarting the game.
