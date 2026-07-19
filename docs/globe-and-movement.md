# Globe & Movement

How the player flies around the planet. Code: [`src/core/sphere.lua`](../src/core/sphere.lua),
[`src/scenes/flight_map.lua`](../src/scenes/flight_map.lua).

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

## Portability note

`math.atan2` (LuaJIT / LÖVE) vs the two-arg `math.atan` (Lua 5.3, used by the
headless test runner) are both handled, so the pure module runs under both.
