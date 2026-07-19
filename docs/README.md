# Design & Decision Docs

Brief records of the non-obvious decisions behind the Flight Map — the main
playable scene. Each doc explains *why* a choice was made, not just what the
code does; read the code for the what.

- [Globe & movement](globe-and-movement.md) — the free-orientation sphere model
  and why we do not use a lat/lon camera.
- [World content & saving](world-content.md) — data-driven countries / airports
  / characters / missions, detection, and persistence.
- [Flight Map scene & mission loop](flight-map.md) — scene structure, game
  states, and the accept → guide → complete cycle.
- [Testing & debug tooling](testing-and-debug.md) — the pure-logic test suite,
  the browser command bridge, and debug keys.
- [Textured globe](textured-globe.md) — the Natural Earth shader globe with
  real continents/countries, its offline asset pipeline, and renderer-independent
  country detection.

The spec these implement lives in [`../specs/flight_map_spec.md`](../specs/flight_map_spec.md).
Section references like "spec §13" point there.
