#!/usr/bin/env python3
"""Offline generator for the Flight Map textured globe.

Turns public-domain Natural Earth country polygons into four aligned assets:

  assets/globe/world_base.png   1024x512 equirectangular color map (the visible
                                globe: each country filled with a distinct calm
                                color, thin borders) — pleasant, readable,
                                educational.
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
import colorsys
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


# ─── Per-country display-colour system ────────────────────────────────────────
# Each country gets a calm, distinct colour on world_base.png.  Thematic where
# the colour evokes the place; varied within continents so neighbours contrast.
# All values are (R, G, B) 0-255 integers.

def hsl(h, s, l):
    """h 0-360°, s/l 0-1 → (R,G,B) 0-255.  colorsys.hls_to_rgb takes (h,l,s)."""
    r, g, b = colorsys.hls_to_rgb(h / 360.0, l, s)
    return (round(r * 255), round(g * 255), round(b * 255))


# Shared neutral colour for micro-states and territories too small to read as
# individual shapes at 1024×512.  Groups them visually without competing with
# their neighbours.
SMALL_LAND = hsl(270, 0.18, 0.78)   # soft neutral lavender-grey

# ISO-2 codes assigned to the small-country group.
SMALL_ISOS = {
    # European micro-states
    "AD", "MC", "LI", "SM", "GI",
    # Caribbean micro-islands
    "BB", "LC", "VC", "GD", "AG", "DM", "KN",
    # Pacific micro-nations
    "KI", "TV", "NR", "PW", "MH", "FM", "WS", "TO", "CK",
    # Small Indian Ocean / Atlantic
    "MV", "SC", "ST", "CV", "KM",
    # Disputed / no-ISO
    "-99",
}

# Per-country display colours.  Keys match the iso field in content/regions.lua.
COUNTRY_COLORS = {
    # ── Europe ───────────────────────────────────────────────────────────────
    "DE": hsl( 30, 0.28, 0.68),  # Germany        – warm stone
    "FR": hsl(280, 0.32, 0.73),  # France         – lavender
    "GB": hsl(200, 0.25, 0.63),  # United Kingdom – slate blue
    "IT": hsl( 18, 0.62, 0.70),  # Italy          – peach terracotta
    "ES": hsl( 38, 0.70, 0.66),  # Spain          – warm amber
    "PT": hsl(135, 0.42, 0.54),  # Portugal       – forest green
    "NL": hsl( 28, 0.75, 0.64),  # Netherlands    – Dutch orange
    "BE": hsl( 46, 0.80, 0.62),  # Belgium        – golden
    "CH": hsl(120, 0.40, 0.62),  # Switzerland    – alpine green
    "AT": hsl(350, 0.52, 0.60),  # Austria        – muted crimson
    "PL": hsl(348, 0.42, 0.65),  # Poland         – dusty rose
    "CZ": hsl(210, 0.48, 0.68),  # Czechia        – cornflower
    "SK": hsl(280, 0.38, 0.56),  # Slovakia       – soft purple
    "HU": hsl( 20, 0.56, 0.64),  # Hungary        – terracotta
    "RO": hsl(105, 0.42, 0.69),  # Romania        – sage green
    "BG": hsl( 90, 0.46, 0.60),  # Bulgaria       – yellow-green
    "RS": hsl( 24, 0.44, 0.57),  # Serbia         – copper
    "HR": hsl(  5, 0.48, 0.57),  # Croatia        – muted red
    "BA": hsl(285, 0.28, 0.63),  # Bosnia         – mauve
    "ME": hsl(175, 0.40, 0.52),  # Montenegro     – teal
    "MK": hsl( 44, 0.56, 0.58),  # N. Macedonia   – golden
    "AL": hsl(  2, 0.52, 0.59),  # Albania        – red
    "GR": hsl(215, 0.52, 0.58),  # Greece         – Mediterranean blue
    "SI": hsl(165, 0.46, 0.50),  # Slovenia       – jade
    "UA": hsl( 55, 0.72, 0.65),  # Ukraine        – wheat yellow
    "BY": hsl(145, 0.40, 0.65),  # Belarus        – forest green
    "MD": hsl( 35, 0.46, 0.60),  # Moldova        – warm amber
    "RU": hsl(205, 0.42, 0.76),  # Russia         – pale ice blue
    "NO": hsl(195, 0.36, 0.44),  # Norway         – fjord
    "SE": hsl(215, 0.54, 0.50),  # Sweden         – Swedish blue
    "FI": hsl(205, 0.48, 0.68),  # Finland        – lake blue
    "DK": hsl(350, 0.52, 0.51),  # Denmark        – Danish red
    "IS": hsl(200, 0.45, 0.71),  # Iceland        – glacial
    "IE": hsl(135, 0.44, 0.47),  # Ireland        – Irish green
    "EE": hsl(200, 0.48, 0.49),  # Estonia        – Baltic blue
    "LV": hsl(350, 0.54, 0.44),  # Latvia         – dark red
    "LT": hsl(130, 0.40, 0.46),  # Lithuania      – green
    "LU": hsl(350, 0.50, 0.46),  # Luxembourg     – red
    "XK": hsl(215, 0.38, 0.58),  # Kosovo         – blue
    "CY": hsl( 42, 0.50, 0.64),  # Cyprus         – sandy
    # ── Asia ─────────────────────────────────────────────────────────────────
    "CN": hsl(138, 0.32, 0.64),  # China          – celadon jade
    "CN-TW": hsl(  0, 0.48, 0.62), # Taiwan       – red
    "JP": hsl(346, 0.68, 0.81),  # Japan          – cherry blossom
    "IN": hsl( 36, 0.78, 0.63),  # India          – saffron
    "KR": hsl(210, 0.52, 0.62),  # South Korea    – sky blue
    "KP": hsl(215, 0.30, 0.57),  # North Korea    – slate
    "VN": hsl(140, 0.48, 0.46),  # Vietnam        – bamboo green
    "TH": hsl( 46, 0.72, 0.65),  # Thailand       – golden
    "MY": hsl( 20, 0.72, 0.65),  # Malaysia       – warm orange
    "ID": hsl(  2, 0.52, 0.58),  # Indonesia      – red
    "PH": hsl(215, 0.52, 0.59),  # Philippines    – blue
    "MM": hsl( 42, 0.78, 0.60),  # Myanmar        – golden
    "KH": hsl(  2, 0.52, 0.57),  # Cambodia       – red
    "LA": hsl(  5, 0.46, 0.54),  # Laos           – dark red
    "BD": hsl(138, 0.45, 0.46),  # Bangladesh     – green
    "LK": hsl( 40, 0.60, 0.55),  # Sri Lanka      – amber
    "NP": hsl(355, 0.56, 0.54),  # Nepal          – crimson
    "BT": hsl( 30, 0.72, 0.62),  # Bhutan         – orange
    "PK": hsl(138, 0.42, 0.44),  # Pakistan       – green
    "AF": hsl( 35, 0.28, 0.54),  # Afghanistan    – tan
    "IR": hsl(138, 0.40, 0.47),  # Iran           – green
    "IQ": hsl( 40, 0.44, 0.54),  # Iraq           – golden
    "SY": hsl( 45, 0.64, 0.63),  # Syria          – sandy
    "JO": hsl( 32, 0.46, 0.62),  # Jordan         – warm sand
    "IL": hsl(205, 0.48, 0.74),  # Israel         – light blue
    "PS": hsl( 44, 0.40, 0.62),  # Palestine      – sandy
    "LB": hsl(  2, 0.52, 0.56),  # Lebanon        – cedar red
    "SA": hsl( 42, 0.52, 0.66),  # Saudi Arabia   – desert sand
    "AE": hsl( 38, 0.46, 0.64),  # UAE            – warm sand
    "OM": hsl( 35, 0.44, 0.61),  # Oman           – sand
    "YE": hsl( 44, 0.58, 0.59),  # Yemen          – golden
    "KW": hsl(138, 0.40, 0.46),  # Kuwait         – green
    "QA": hsl(345, 0.54, 0.44),  # Qatar          – maroon
    "BH": hsl(  2, 0.48, 0.55),  # Bahrain        – red
    "TR": hsl( 12, 0.52, 0.56),  # Turkey         – terracotta
    "GE": hsl(  0, 0.50, 0.56),  # Georgia        – red cross
    "AM": hsl(  5, 0.48, 0.54),  # Armenia        – red
    "AZ": hsl(200, 0.52, 0.48),  # Azerbaijan     – blue
    "KZ": hsl(205, 0.50, 0.52),  # Kazakhstan     – sky blue
    "UZ": hsl(208, 0.52, 0.54),  # Uzbekistan     – blue
    "TM": hsl(138, 0.42, 0.46),  # Turkmenistan   – green
    "KG": hsl(  2, 0.54, 0.55),  # Kyrgyzstan     – red
    "TJ": hsl(  5, 0.52, 0.55),  # Tajikistan     – red
    "MN": hsl(348, 0.48, 0.44),  # Mongolia       – dark red
    "BN": hsl( 44, 0.52, 0.58),  # Brunei         – golden
    "TL": hsl(  2, 0.46, 0.54),  # Timor-Leste    – red
    "SG": hsl(  0, 0.46, 0.60),  # Singapore      – red (territory)
    # ── Africa ───────────────────────────────────────────────────────────────
    "EG": hsl( 46, 0.62, 0.70),  # Egypt          – sandy gold
    "LY": hsl( 44, 0.58, 0.68),  # Libya          – sand
    "TN": hsl( 22, 0.52, 0.62),  # Tunisia        – terracotta
    "DZ": hsl( 42, 0.52, 0.65),  # Algeria        – ochre
    "MA": hsl( 24, 0.48, 0.56),  # Morocco        – desert
    "EH": hsl( 38, 0.36, 0.65),  # Western Sahara – lighter sand
    "ET": hsl( 94, 0.46, 0.56),  # Ethiopia       – savanna green
    "KE": hsl( 40, 0.56, 0.52),  # Kenya          – amber
    "NG": hsl(138, 0.42, 0.48),  # Nigeria        – green
    "ZA": hsl( 20, 0.46, 0.61),  # South Africa   – warm terracotta
    "GH": hsl( 40, 0.54, 0.52),  # Ghana          – golden
    "CI": hsl( 28, 0.70, 0.62),  # Ivory Coast    – orange
    "TZ": hsl(192, 0.44, 0.50),  # Tanzania       – teal blue
    "MG": hsl(  2, 0.52, 0.56),  # Madagascar     – red
    "CD": hsl( 42, 0.44, 0.56),  # DR Congo       – golden
    "AO": hsl(  2, 0.48, 0.54),  # Angola         – red
    "MZ": hsl( 42, 0.58, 0.62),  # Mozambique     – golden
    "ZM": hsl( 32, 0.62, 0.58),  # Zambia         – copper/orange
    "ZW": hsl(  2, 0.48, 0.54),  # Zimbabwe       – red
    "SD": hsl( 40, 0.46, 0.64),  # Sudan          – warm sand
    "SS": hsl( 38, 0.40, 0.60),  # South Sudan    – tan
    "CM": hsl(138, 0.42, 0.46),  # Cameroon       – green
    "GA": hsl(135, 0.40, 0.48),  # Gabon          – green
    "BF": hsl( 44, 0.50, 0.58),  # Burkina Faso   – golden
    "ML": hsl( 42, 0.52, 0.60),  # Mali           – golden
    "NE": hsl( 46, 0.56, 0.65),  # Niger          – sandy
    "TD": hsl( 30, 0.34, 0.54),  # Chad           – brownish
    "MR": hsl( 38, 0.44, 0.60),  # Mauritania     – sandy
    "SO": hsl(205, 0.52, 0.60),  # Somalia        – light blue
    "ER": hsl(200, 0.44, 0.54),  # Eritrea        – blue
    "DJ": hsl(192, 0.42, 0.52),  # Djibouti       – teal
    "UG": hsl(138, 0.42, 0.47),  # Uganda         – green
    "RW": hsl(142, 0.40, 0.47),  # Rwanda         – green
    "BI": hsl(  8, 0.46, 0.55),  # Burundi        – red
    "SN": hsl(138, 0.40, 0.47),  # Senegal        – green
    "NA": hsl( 40, 0.44, 0.67),  # Namibia        – sandy
    "BW": hsl(  0, 0.00, 0.72),  # Botswana       – grey (diamonds)
    "LS": hsl(135, 0.38, 0.48),  # Lesotho        – green
    "SZ": hsl(225, 0.50, 0.46),  # Eswatini       – blue
    "MW": hsl(138, 0.38, 0.48),  # Malawi         – green
    "CG": hsl(140, 0.40, 0.46),  # Congo-Brazzaville – green
    "CF": hsl(  2, 0.48, 0.55),  # Central African Republic – red
    "GN": hsl(  2, 0.48, 0.54),  # Guinea         – red
    "SL": hsl(200, 0.44, 0.50),  # Sierra Leone   – blue
    "LR": hsl(  3, 0.48, 0.54),  # Liberia        – red
    "GW": hsl( 44, 0.52, 0.60),  # Guinea-Bissau  – golden
    "TG": hsl(138, 0.38, 0.46),  # Togo           – green
    "BJ": hsl( 46, 0.58, 0.64),  # Benin          – yellow
    "GM": hsl(  3, 0.46, 0.54),  # Gambia         – red
    "GQ": hsl(142, 0.38, 0.46),  # Equatorial Guinea – green
    "NC": hsl(182, 0.40, 0.52),  # New Caledonia  – teal
    "GF": hsl(142, 0.38, 0.48),  # French Guiana  – green
    # ── Americas ─────────────────────────────────────────────────────────────
    "US": hsl(210, 0.52, 0.62),  # USA            – denim blue
    "CA": hsl(  2, 0.50, 0.60),  # Canada         – maple red
    "MX": hsl(138, 0.42, 0.48),  # Mexico         – cactus green
    "BR": hsl(140, 0.48, 0.50),  # Brazil         – tropical green
    "AR": hsl(205, 0.52, 0.63),  # Argentina      – sky blue
    "CL": hsl(  2, 0.50, 0.54),  # Chile          – red
    "CO": hsl( 46, 0.65, 0.61),  # Colombia       – yellow
    "VE": hsl( 48, 0.62, 0.61),  # Venezuela      – yellow
    "PE": hsl(  3, 0.48, 0.55),  # Peru           – red
    "BO": hsl( 42, 0.58, 0.62),  # Bolivia        – golden
    "PY": hsl(  4, 0.48, 0.55),  # Paraguay       – red
    "UY": hsl(205, 0.50, 0.62),  # Uruguay        – blue
    "EC": hsl( 44, 0.66, 0.62),  # Ecuador        – yellow
    "GY": hsl(138, 0.40, 0.46),  # Guyana         – green
    "SR": hsl(142, 0.38, 0.46),  # Suriname       – green
    "GL": hsl(200, 0.42, 0.80),  # Greenland      – glacial blue
    "CU": hsl(205, 0.46, 0.52),  # Cuba           – blue
    "JM": hsl( 84, 0.44, 0.46),  # Jamaica        – green
    "HT": hsl(222, 0.46, 0.49),  # Haiti          – blue
    "DO": hsl(207, 0.44, 0.50),  # Dominican Rep  – blue
    "GT": hsl(207, 0.44, 0.52),  # Guatemala      – blue
    "BZ": hsl(140, 0.38, 0.46),  # Belize         – green
    "HN": hsl(207, 0.42, 0.52),  # Honduras       – blue
    "SV": hsl(209, 0.42, 0.52),  # El Salvador    – blue
    "NI": hsl(211, 0.42, 0.52),  # Nicaragua      – blue
    "CR": hsl(205, 0.40, 0.52),  # Costa Rica     – blue
    "PA": hsl(203, 0.42, 0.52),  # Panama         – blue
    "TT": hsl(  2, 0.48, 0.55),  # Trinidad       – red
    "PR": hsl(  4, 0.46, 0.55),  # Puerto Rico    – red
    "BS": hsl(192, 0.50, 0.60),  # Bahamas        – teal
    "FK": hsl(207, 0.40, 0.54),  # Falklands      – blue
    "TF": hsl(195, 0.35, 0.62),  # Fr. S. Antarctic Lands – teal
    # ── Oceania ──────────────────────────────────────────────────────────────
    "AU": hsl( 22, 0.50, 0.60),  # Australia      – red ochre
    "NZ": hsl(185, 0.44, 0.49),  # New Zealand    – teal
    "PG": hsl( 42, 0.62, 0.59),  # Papua New Guinea – golden
    "FJ": hsl(205, 0.48, 0.60),  # Fiji           – blue
    "SB": hsl(208, 0.46, 0.60),  # Solomon Islands – blue
    "VU": hsl(140, 0.42, 0.48),  # Vanuatu        – green
    # ── Antarctica ───────────────────────────────────────────────────────────
    "AQ": hsl(210, 0.28, 0.90),  # Antarctica     – glacial white-blue
}


def get_country_color(iso, continent):
    """Return (R,G,B) display colour for one country.
    Priority: specific override → small-territory group → continent fallback."""
    if iso in SMALL_ISOS:
        return SMALL_LAND
    c = COUNTRY_COLORS.get(iso)
    if c:
        return c
    # Continent fallback: convert the existing 0-1 floats to 0-255.
    fc = CONTINENT_COLORS.get(continent, DEFAULT_LAND)
    return tuple(round(v * 255) for v in fc)


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

        land_rgb = get_country_color(iso, continent)
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
    write_country_colors_lua(regions)


def write_country_colors_lua(regions):
    """Emit content/country_colors.lua: ISO -> display RGB for every country.
    The small-territory group and continent fallbacks are resolved here so the
    Lua table always has concrete values — no lookup logic needed at runtime."""
    path = os.path.join(REPO, "content", "country_colors.lua")
    lines = [
        "-- GENERATED by scripts/gen-globe-assets.py -- do not edit by hand.",
        "-- Display colour for every country on world_base.png.",
        "-- Keys are ISO-2 codes (matching content/regions.lua).  RGB 0-255.",
        "-- Small territories share a common neutral colour (SMALL_LAND group).",
        "local M = {}",
        "",
    ]
    for reg in regions:
        iso = reg["iso"]
        rgb = get_country_color(iso, reg["continent"])
        r, g, b = rgb
        lines.append(f'M[{lua_str(iso)}] = {{ {r}, {g}, {b} }}  -- {reg["name"]}')
    lines += ["", "return M", ""]
    with open(path, "w") as f:
        f.write("\n".join(lines))
    print(f"wrote {path} ({len(regions)} entries)")


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
