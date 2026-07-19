#!/usr/bin/env python3
"""Offline generator for the Flight Map textured globe.

Turns public-domain Natural Earth country polygons into three aligned assets:

  assets/globe/world_base.png   1024x512 equirectangular color map (the visible
                                globe: ocean + land shaded by continent, thin
                                borders) — pleasant, low-noise, educational.
  assets/globe/country_ids.png  1024x512 equirectangular ID mask: every country
                                is one FLAT unique RGB color, ocean is black.
                                No antialiasing, no gradients — for pixel lookup.
  content/regions.lua           color -> { id, name, iso, continent } table so
                                game logic resolves a country from a pixel
                                without knowing anything about the renderer.

Both PNGs are produced by the SAME rasterizer in the SAME projection, so they
are pixel-aligned by construction — no drift between the visible map and the
mask used for detection and highlighting.

Requires only python3 + Pillow. No GDAL/ogr2ogr. Network is used once to fetch
the Natural Earth GeoJSON (public domain, naturalearthdata.com).

Usage:  python3 scripts/gen-globe-assets.py [--res 1024x512] [--source 110m|50m]
"""

import argparse
import json
import math
import os
import sys
import urllib.request

try:
    from PIL import Image, ImageDraw
except ImportError:
    sys.exit("Pillow is required: pip install Pillow")

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Natural Earth vector, GeoJSON mirror (public domain). 110m is plenty for a
# 1024x512 target and keeps small features from turning to mush; 50m is offered
# for a crisper mask if the device budget allows.
SOURCES = {
    "110m": "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_admin_0_countries.geojson",
    "50m": "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_50m_admin_0_countries.geojson",
}

# Continent -> base land color for the visible map. Muted, distinct, low-noise
# so the globe reads as a friendly reference map rather than a busy atlas.
CONTINENT_COLORS = {
    "North America": (0.83, 0.72, 0.52),
    "South America": (0.70, 0.80, 0.55),
    "Europe": (0.80, 0.66, 0.60),
    "Africa": (0.88, 0.78, 0.50),
    "Asia": (0.74, 0.72, 0.56),
    "Oceania": (0.62, 0.78, 0.70),
    "Antarctica": (0.90, 0.92, 0.95),
    "Seven seas (open ocean)": (0.16, 0.42, 0.70),
}
DEFAULT_LAND = (0.78, 0.74, 0.58)
OCEAN = (0.16, 0.42, 0.70)
BORDER = (0.32, 0.30, 0.26)


def slug(name):
    """A stable lowercase id from a country name (matches content/world.lua ids
    where they overlap, e.g. 'United States of America' would need a manual map;
    we key game countries by ISO instead — see regions.lua consumers)."""
    out = []
    for ch in name.lower():
        if ch.isalnum():
            out.append(ch)
        elif out and out[-1] != "_":
            out.append("_")
    return "".join(out).strip("_")


def id_color(index):
    """Map a 1-based country index to a flat, unique, non-black RGB.

    Base-12 spread across the three channels: 12^3 = 1728 unique combos, each
    channel a multiple of 18 offset from 30 so colors are >=30 (never the black
    reserved for ocean) and >=18 apart (safe for nearest-filter exact match on
    the GPU, and unambiguous for CPU lookup). Deterministic, so regions.lua can
    be written directly with no read-back."""
    step = 18
    base = 30
    r = base + (index % 12) * step
    g = base + ((index // 12) % 12) * step
    b = base + ((index // 144) % 12) * step
    return (r, g, b)


def fetch_geojson(source):
    url = SOURCES[source]
    cache = os.path.join(REPO, "scripts", ".cache", f"ne_{source}_countries.geojson")
    os.makedirs(os.path.dirname(cache), exist_ok=True)
    if not os.path.exists(cache):
        print(f"downloading {url}")
        try:
            urllib.request.urlretrieve(url, cache)
        except Exception as e:
            # python.org Python on macOS often lacks CA certs; curl has them.
            print(f"urllib failed ({e}); falling back to curl")
            import subprocess

            subprocess.run(["curl", "-sSL", "--fail", "-o", cache, url], check=True)
    with open(cache) as f:
        return json.load(f)


def rings_of(geometry):
    """Yield each outer ring as a list of (lon, lat). Holes are ignored: at
    1024x512 country holes (e.g. Lesotho inside South Africa) are handled by
    the 1024x512 target country holes (e.g. Lesotho inside South Africa) are
    handled by draw order well enough, and the ID mask favors solid fills."""
    t = geometry["type"]
    coords = geometry["coordinates"]
    if t == "Polygon":
        yield coords[0]
    elif t == "MultiPolygon":
        for poly in coords:
            yield poly[0]


def unwrap(ring):
    """Remove antimeridian jumps: walk the ring and keep longitude continuous by
    adding/subtracting 360 whenever consecutive points jump more than 180deg.
    A ring that truly straddles the dateline (Russia, Fiji) ends up in a
    continuous longitude band beyond [-180,180]; the caller draws it three times
    (at x, x-W, x+W) so the wrapped part lands correctly instead of smearing."""
    out = []
    prev = None
    for lon, lat in ring:
        if prev is not None:
            while lon - prev > 180:
                lon -= 360
            while lon - prev < -180:
                lon += 360
        out.append((lon, lat))
        prev = lon
    return out


def to_pixels(ring, W, H):
    pts = []
    for lon, lat in ring:
        x = (lon + 180.0) / 360.0 * W
        y = (90.0 - lat) / 180.0 * H
        pts.append((x, y))
    return pts


def draw_ring(draw, ring, W, H, fill, outline=None):
    """Fill a lon/lat ring, drawing it shifted by -W, 0, +W so dateline-wrapping
    polygons render on both sides of the seam. PIL clips the off-canvas copies."""
    pts = to_pixels(unwrap(ring), W, H)
    if len(pts) < 3:
        return
    for dx in (-W, 0, W):
        shifted = [(x + dx, y) for x, y in pts]
        draw.polygon(shifted, fill=fill, outline=outline)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--res", default="1024x512", help="WxH, must be 2:1 and ideally power-of-two")
    ap.add_argument("--source", default="110m", choices=SOURCES.keys())
    args = ap.parse_args()
    W, H = (int(v) for v in args.res.lower().split("x"))
    assert W == 2 * H, "equirectangular must be 2:1"

    data = fetch_geojson(args.source)
    features = data["features"]

    # Stable ordering so ids/colors don't shuffle between runs.
    def key(ft):
        p = ft["properties"]
        return (p.get("NAME") or p.get("ADMIN") or "").lower()

    features.sort(key=key)

    base = Image.new("RGB", (W, H), tuple(int(c * 255) for c in OCEAN))
    ids = Image.new("RGB", (W, H), (0, 0, 0))  # ocean = black
    base_draw = ImageDraw.Draw(base)
    ids_draw = ImageDraw.Draw(ids)

    regions = []
    index = 0
    for ft in features:
        p = ft["properties"]
        name = p.get("NAME") or p.get("ADMIN") or "unknown"
        iso = p.get("ISO_A2") or "-"
        iso3 = p.get("ISO_A3") or "-"
        continent = p.get("CONTINENT") or "-"
        name_ru = p.get("NAME_RU") or name
        name_de = p.get("NAME_DE") or name
        index += 1
        color = id_color(index)

        land = CONTINENT_COLORS.get(continent, DEFAULT_LAND)
        land_rgb = tuple(int(c * 255) for c in land)
        border_rgb = tuple(int(c * 255) for c in BORDER)

        for ring in rings_of(ft["geometry"]):
            draw_ring(base_draw, ring, W, H, fill=land_rgb, outline=border_rgb)
            # ID mask: NO outline (outline would introduce a non-country color at
            # borders); flat fill only, so every land pixel maps to exactly one id.
            draw_ring(ids_draw, ring, W, H, fill=color, outline=None)

        regions.append(
            {
                "id": slug(name),
                "name": name,
                "name_ru": name_ru,
                "name_de": name_de,
                "iso": iso,
                "iso3": iso3,
                "continent": continent,
                "color": color,
            }
        )

    out_dir = os.path.join(REPO, "assets", "globe")
    os.makedirs(out_dir, exist_ok=True)
    base.save(os.path.join(out_dir, "world_base.png"))
    ids.save(os.path.join(out_dir, "country_ids.png"))
    print(f"wrote {out_dir}/world_base.png and country_ids.png ({W}x{H}, {index} countries)")

    write_regions_lua(regions)


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_regions_lua(regions):
    """Emit content/regions.lua: a color-keyed lookup plus the ordered list.
    Key is 'r,g,b' (0..255 ints) so the runtime picker can index it directly."""
    path = os.path.join(REPO, "content", "regions.lua")
    lines = []
    lines.append("-- GENERATED by scripts/gen-globe-assets.py -- do not edit by hand.")
    lines.append("-- Maps the flat RGB colors in assets/globe/country_ids.png to country")
    lines.append("-- metadata, so game logic resolves a country from a pixel without any")
    lines.append("-- renderer knowledge. Source: Natural Earth (public domain, naturalearthdata.com).")
    lines.append("--")
    lines.append("-- `byColor` is keyed by \"r,g,b\" (0..255). `list` preserves generation order.")
    lines.append("local byColor = {}")
    lines.append("local list = {}")
    lines.append("")
    for reg in regions:
        r, g, b = reg["color"]
        key = f"{r},{g},{b}"
        entry = (
            "{ id = %s, name = %s, name_ru = %s, name_de = %s, iso = %s, iso3 = %s, continent = %s, color = { %d, %d, %d } }"
            % (
                lua_str(reg["id"]),
                lua_str(reg["name"]),
                lua_str(reg["name_ru"]),
                lua_str(reg["name_de"]),
                lua_str(reg["iso"]),
                lua_str(reg["iso3"]),
                lua_str(reg["continent"]),
                r,
                g,
                b,
            )
        )
        lines.append(f"local e = {entry}")
        lines.append(f'byColor["{key}"] = e')
        lines.append("list[#list + 1] = e")
        lines.append("")
    lines.append("return { byColor = byColor, list = list }")
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"wrote {path} ({len(regions)} entries)")


if __name__ == "__main__":
    main()
