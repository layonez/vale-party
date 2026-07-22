# Textured globe

How the Flight Map renders the planet: an equirectangular Natural Earth texture
projected onto a sphere by a fragment shader, with the mission target and the
recognized country filled on their real shapes. Code:
[`src/core/globe_shader.lua`](../src/core/globe_shader.lua),
[`src/core/globe_regions.lua`](../src/core/globe_regions.lua). Assets are
generated offline by [`scripts/gen-globe-assets.py`](../scripts/gen-globe-assets.py).

## Pieces

| File | Role |
| --- | --- |
| `scripts/gen-globe-assets.py` | Offline generator. Downloads Natural Earth 110m country polygons (public domain) and rasterizes them with **Pillow** (no GDAL) into aligned assets. |
| `assets/globe/world_base.png` | 1024×512 equirectangular **visible** map: ocean + per-country thematic fill + thin borders. ~177 countries each have a hand-curated calm, evocative color; micro-states and disputed territories share a soft lavender-grey. Friendly, low-noise — educational, not a busy atlas. |
| `assets/globe/country_ids.png` | 1024×512 equirectangular **ID mask**: each country one flat unique RGB, ocean black. No antialiasing. |
| `content/regions.lua` | Generated `color → { id, name, name_ru, name_de, iso, iso3, continent }` map. Includes Russian/German names straight from Natural Earth, ready for localization. |
| `content/country_colors.lua` | Generated `ISO → {R, G, B}` table (0–255) for every country. Mirrors what was baked into `world_base.png`; available at runtime if needed for UI tinting. |
| `src/core/globe_shader.lua` | The sphere renderer. `pcall`-guarded shader compile; nil on failure so the Flight Map falls back to the vector renderer. |
| `src/core/globe_regions.lua` | Renderer-independent CPU picking: `lat/lon → equirect pixel → flat RGB → country id`. `.fromImageData` injection makes the math unit-testable headless. |

The visible texture and the ID mask are produced by the same rasterizer in the
same projection, so they are pixel-aligned by construction — no drift between
the map you see and the mask used for detection/highlighting.

## Why these decisions

**Orthographic shader, not a 3D engine.** The globe already lives as a 3×3
world→view orientation (`src/core/sphere.lua`). The fragment shader inverts
`Sphere.project` per pixel: for a disc pixel `(u,v)` the near-hemisphere view
vector is `(sqrt(1-u²-v²), u, v)`, and `world = viewX·fwd + viewY·right +
viewZ·up` (the transpose of the orthonormal orientation, computed without
`transpose()`, which GLSL ES 1.00 lacks). Then `lat=asin(z)`, `lon=atan2(y,x)`,
into equirect UV. This reproduces the existing projection exactly, so the vector
overlays drawn via `Sphere.project` (graticule, characters) stay pixel-aligned on
top of the textured sphere, and we add no camera model.

**Orientation passed as three `vec3` rows**, not a `mat3` — avoids LÖVE's
row/column-major ambiguity and keeps GLSL ES 1.00 happy.

**No mipmaps + `repeat` wrap fixes the longitude seam.** The classic
antimeridian seam is a mipmap artifact: `atan` jumps ~2π over one pixel, the
derivative explodes, and the GPU picks the coarsest mip → a blurry vertical
line. Sampling the base level always, with `repeat` wrap so the bilinear tap at
the dateline blends the correct adjacent longitudes, removes it. This is why the
texture must be **power-of-two** (OpenGL ES 2 forbids `repeat` on NPOT).

**No explicit `precision` qualifier in the shader.** Forcing `precision highp
float;` compiles on desktop GL but **fails under WebGL / GLSL ES** (`'highp':
overloaded functions must have the same parameter precision qualifiers`) because
LÖVE's shader header has already resolved the built-in overloads at its default
precision. Omitting the qualifier compiles on both desktop and GLSL ES — the
same dialect family as the RG35XX.

**ID mask uses `nearest` filtering and flat colors.** Any blending at borders
would produce in-between colors matching no country. Detection scales LÖVE 11's
0..1 float pixels back to 0..255 ints and looks up the exact color.

**Detection stays layered, not swapped.** Gameplay and recognition keep using
`World:countryAt` (great-circle region circles for the playable countries,
intentionally larger than the real borders per spec §7, and headless-testable).
`GlobeRegions` is additive — it resolves any of the ~200 Natural Earth countries
from a pixel, used for highlighting. Swapping recognition onto the texture would
change behavior at country edges, so it is deliberately not done.

**Highlights are filled shapes, keyed by ISO.** The mission target (vivid green
+ pulsing near-white outline) and recognized country (amber fill + outline) are
drawn on their real shapes by the shader, which tints texels whose ID-mask color
matches. Each game country in `content/world.lua` carries an `iso` field; the
scene resolves it to a mask color once via `GlobeRegions:colorForIso`. ISO is
the join key because the game's ids (`usa`) differ from Natural Earth slugs
(`united_states_of_america`). A country missing from the mask simply isn't
filled — the fallback vector renderer still draws its outline ring.

**Border trace + contrast.** For legibility the target gets both a bold interior
fill and a thick bright border traced along the real coastline: the shader marks
a texel as "border" when it is inside the country but has a differently-colored
ID-mask neighbor `uBorderW` texels away (`zoneFor` in `globe_shader.lua`).
`uBorderW` (default 4 texels) is the single knob for border thickness; the fill
and outline colors are the `mix(...)` constants in the same block.

**Graceful fallback.** If the shader or assets fail to load (older GPU, GLES
quirk), `GlobeShader.new` returns nil and `flight_map.lua` draws the previous
simplified vector renderer — flat ocean + `Landmass` continents + great-circle
outline highlights. Nothing hard-depends on the shader, so the scene always
renders.

## Regenerating assets

```sh
python3 scripts/gen-globe-assets.py                 # 110m, 1024x512 (default)
python3 scripts/gen-globe-assets.py --source 50m --res 2048x1024   # crisper
```

Only `python3` + Pillow are needed. The GeoJSON is cached under `scripts/.cache/`
(git-ignored, re-fetched on demand). Note: python.org's macOS Python often lacks
CA certs, so the script falls back to `curl` for the download.

The generator produces three outputs: `assets/globe/world_base.png`,
`assets/globe/country_ids.png`, and `content/country_colors.lua`.

Source data: **Natural Earth** (public domain, naturalearthdata.com).

## Known limits

- **Not yet frame-timed on the RG35XX Plus.** The shader targets GLSL ES 1.00
  (`#pragma language glsl1`, no `transpose`, no mipmaps, floats only) and renders
  cleanly under desktop GL and WebGL, but per-pixel `asin`/`atan`/`sqrt` over the
  disc at 640×480 wants a real check on the Mali-G31. If it is too slow, drop to
  a 512×256 texture; if the shader fails to compile the vector fallback covers it.
- **1024×512 softens small coastlines** at the full display radius of 396. Fine
  for a friendly reference globe; regenerate at 2048×1024 if the device budget
  allows.
- **Antarctica / country holes:** the generator fills outer rings only and skips
  holes (e.g. Lesotho) — acceptable at this resolution.
- Natural Earth marks a few countries (France, Norway, Kosovo…) with
  `ISO_A2 = -99`; their id/name still resolve, only the ISO code is a placeholder.
