# Globe & Movement

How the player flies around the planet. Code: [`src/core/sphere.lua`](../src/core/sphere.lua),
[`src/scenes/flight_map.lua`](../src/scenes/flight_map.lua).

## Opening zoom animation

When the Flight Map scene loads, the globe zooms in over **4 seconds** from a
small distant view (`radius 210`, centered at `y=250`) to its full size
(`radius 396`, centered at `y=320`). The transition uses a quadratic ease-out
so it decelerates as it settles. The plane and HUD appear at their final sizes
from the start; only the globe itself animates.

`GLOBE` (the single mutable table the renderer reads each frame) is driven by
`self.zoomT` (0→1). On `enter()` it is reset to the start values so restarting
always replays the animation.

## Free 3D orientation, not a lat/lon camera

**Decision:** The globe's state is a full 3×3 orientation matrix (world→view),
and flight rotates it about **screen-fixed axes** — up/down turns about the
screen's horizontal axis, left/right about the vertical. The airplane is pinned
at screen center; the world rotates beneath it.

**Why not track a camera latitude/longitude and increment it?** That was the
first implementation, and it has a coordinate singularity at the poles: "up"
always walks along a meridian straight to the geographic pole, where all
meridians converge and movement degenerates — you reach the pole and effectively
stall. Incrementing lon near the pole also spins the view wildly.

The orientation model has no such singularity. "Up" traces whichever great
circle is currently vertical, so you fly straight *over* a pole and keep going
onto the far side. This is verified by the tests
`flying up over the pole stays continuous` and
`turning up by 90 deg lands exactly on the pole`.

**Cost:** we re-orthonormalize the matrix after each turn to shed floating-point
drift (`orientation stays orthonormal after many turns` guards this). The world
position "beneath" the plane is derived on demand via `Sphere.front`.

## Orthographic projection + horizon culling

`Sphere.project` maps a world lat/lon into view space; a point is visible when
its depth component (toward the viewer) is ≥ 0, i.e. on the near hemisphere.
Everything drawn on the globe — graticule, continents, country outlines,
characters — uses this and simply skips points that fail the visibility test, so
geometry disappears naturally at the horizon with no explicit clipping.

`Sphere.screenDirection` returns the on-screen azimuth toward a world point and
works **even when the point is behind the horizon** — that is what lets the
target arrow (spec §13) point toward a target that is not yet visible.

## Movement feel

Constant angular speed, no acceleration or inertia, stops immediately on
release, no diagonal (spec §6). Conflicting directions resolve consistently
(vertical wins). See `turnDelta` in the scene.

**Latitude speed curve.** The same angular step covers different visual distances
depending on where the plane sits: at the equator the globe surface is moving
fastest, making diagonal runs feel sluggish compared to straight east/west
sprints at mid-latitude. To even this out, the scene applies a `latSpeedFactor`
that reads the current camera latitude and smoothly slows the step to **60%** at
the equator (|lat| = 0°), recovering to 100% at |lat| = 50° and above. The
transition is linear between those anchors, so the control always feels
proportional to what the player sees.

## Plane sprite & facing

Code: [`src/ui/plane.lua`](../src/ui/plane.lua).

The plane is an 8-direction sprite from `assets/sprites/plane.png` — a 3×3
compass sheet (center cell empty) of the kid in a plane facing N/NE/E/SE/S/SW/
W/NW. It stays pinned at screen center and we swap which cell is drawn to face
the travel direction (spec §4). Idle keeps the last facing; the default is south
(facing the viewer).

**Turns rotate through the intermediate tiles, not snap.** Input is only
4-directional, so a naive mapping would use just 4 of the 8 tiles and flip
instantly. Instead the sheet is treated as a compass ring and the drawn facing
steps **one tile at a time along the shortest arc** toward the target facing
(`Plane.stepToward`), at a fixed rate (~0.06s/tile, `FACING_STEP_TIME` in the
scene). So a west→east turn visibly spins through nw/n/ne (or sw/s/se), using all
eight sprites. Ties (exact opposite) resolve clockwise, consistently. The
stepping is pure and unit-tested; the sheet loads lazily so the module can be
required without a live graphics context.

## Portability note

`math.atan2` (LuaJIT / LÖVE) vs the two-arg `math.atan` (Lua 5.3, used by the
headless test runner) are both handled, so the pure module runs under both.
