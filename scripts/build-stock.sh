#!/usr/bin/env sh
# Build a COMPLETE, installable RG35XX Plus stock-firmware package.
#
# Unlike a scaffold, this bundles a real aarch64 LOVE 11.4 runtime plus every
# non-system shared library the runtime needs, so the package boots on the
# device with no manual file preparation. See platform/stock/README.md for the
# runtime provenance, licenses, and the (device-only) validation checklist.
#
# Portable across macOS and Linux CI: uses only sh, curl, ar, tar (bsdtar or
# GNU tar with zstd support), sha256sum/shasum, and zip. No dpkg required.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

CACHE="scripts/.cache/stock"
mkdir -p "$CACHE"

# ---------------------------------------------------------------------------
# Runtime + library manifest (pinned for reproducibility).
#
# LOVE 11.4 aarch64 runtime: Cebion/love2d_aarch64, the build PortMaster uses on
# Allwinner H700 handhelds. LOVE is zlib-licensed. Files are committed in the
# repo (no releases), pinned here by raw URL + sha256.
#
# Supporting libraries: Ubuntu 22.04 "jammy" arm64 .debs from ports.ubuntu.com.
# The RG35XX Plus stock firmware IS Ubuntu 22.04 (glibc 2.35), so these match
# the device ABI exactly. Every pinned lib requires <= GLIBC_2.34.
#
# NOT bundled, provided by the device: libSDL2 and its display/audio backends
# (X11, wayland, GL/EGL, ALSA, PulseAudio, libc, libstdc++, ...). Stock firmware
# ships a panel-tuned SDL2 (it runs RetroArch); a generic SDL2 could fail to
# drive the 640x480 display, so we deliberately rely on the device's copy.
# ---------------------------------------------------------------------------

CEBION_RAW="https://raw.githubusercontent.com/Cebion/love2d_aarch64/main/11.4"
UBU="http://ports.ubuntu.com/ubuntu-ports"

# Cebion runtime files: "url|sha256|destname"
CEBION_FILES="\
$CEBION_RAW/love|660b03a982f39f7c83f7823d9a79191620bf1d579b952b322014e6330e66a05e|love
$CEBION_RAW/libs/liblove-11.4.so|06807bb0c494cbee395fea37af49fa60d3b1c7d61f0cefd11fab9f3a27740914|liblove-11.4.so
$CEBION_RAW/libs/libluajit-5.1.so.2|256284414573afd65e1f70e68c515304d71f230e1a78f6b1fcd406614f4dbb1e|libluajit-5.1.so.2"

# jammy .debs: "poolpath|sha256". The .so files inside land in libs/ verbatim.
DEB_FILES="\
$UBU/pool/main/f/freetype/libfreetype6_2.11.1+dfsg-1ubuntu0.3_arm64.deb|2dfec0077df5cef76c6247610ed4d164ec6ce27fb2982313275ead0832ac745d
$UBU/pool/main/libp/libpng1.6/libpng16-16_1.6.37-3ubuntu0.5_arm64.deb|cfef653a7634549ecd4bd17f6e7cc44e1dec34fc1fcf36269e21415ec406e9bc
$UBU/pool/main/b/brotli/libbrotli1_1.0.9-2build6_arm64.deb|6ce71a1452d7ec3ed2404db11a4d0aea1326b8fa9bb904493b49ff873b70d6a5
$UBU/pool/universe/libm/libmodplug/libmodplug1_0.8.9.0-3_arm64.deb|a354c5aa85a6b6fa35623588afd845f960b23485b69c16a3fd1b8ba1b0c0b38c
$UBU/pool/main/m/mpg123/libmpg123-0_1.29.3-1ubuntu0.1_arm64.deb|4a9a2ee385035bffe3c8accc974cc5272a402227d00196e8c7a2e9946ae90ae4
$UBU/pool/universe/o/openal-soft/libopenal1_1.19.1-2build3_arm64.deb|e43d76e5ada49abd01ec2384732bfe6f15a1dd1adef8605c15c3cb0387e2aa75
$UBU/pool/main/libt/libtheora/libtheora0_1.1.1+dfsg.1-15ubuntu4_arm64.deb|d1e1c6aed63c30ae5f5653b34b6cc22ca339e833549be0e9ca19f1eb3e9b4315
$UBU/pool/main/libv/libvorbis/libvorbis0a_1.3.7-1build2_arm64.deb|bf1b1c79b8953e077c19fc1015972b2f8e16521e41d4596e2f7e3d91811ea4d0
$UBU/pool/main/libv/libvorbis/libvorbisfile3_1.3.7-1build2_arm64.deb|56cebf5da54aee5e0de0a5b638b9af78bb2bdca97defaff4053bb30326054182
$UBU/pool/main/libo/libogg/libogg0_1.3.5-0ubuntu3_arm64.deb|6072fff3bdc02037b2cc4dd5ee421bdb5a656eb2f70563e940fb0d967ee70332"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

sha256_of() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$1" | cut -d' ' -f1
	else
		shasum -a 256 "$1" | cut -d' ' -f1
	fi
}

# fetch <url> <sha256> <cachefile> — download once, then verify checksum.
fetch() {
	url=$1
	want=$2
	out=$3
	if [ ! -f "$out" ]; then
		echo "  download $(basename "$out")"
		curl -fsSL -o "$out.part" "$url"
		mv "$out.part" "$out"
	fi
	got=$(sha256_of "$out")
	if [ "$got" != "$want" ]; then
		echo "checksum mismatch for $url" >&2
		echo "  expected $want" >&2
		echo "  actual   $got" >&2
		rm -f "$out"
		exit 1
	fi
}

# extract_so <deb> <destdir> — pull every *.so* file out of a .deb's data
# member into destdir, flattened. Uses ar + tar; bsdtar (macOS) and GNU tar
# with zstd both decompress data.tar.zst transparently.
extract_so() {
	deb=$1
	dest=$2
	# ar runs inside a temp dir, so pass it an absolute path.
	case "$deb" in
		/*) ;;
		*) deb="$ROOT/$deb" ;;
	esac
	work=$(mktemp -d)
	( cd "$work" && ar x "$deb" )
	data=$(ls "$work"/data.tar.* 2>/dev/null | head -1)
	if [ -z "$data" ]; then
		echo "no data member in $deb" >&2
		rm -rf "$work"
		exit 1
	fi
	tar -xf "$data" -C "$work"
	# Copy real .so files (skip symlinks; we recreate a stable soname below).
	find "$work" -type f -name '*.so*' | while IFS= read -r f; do
		cp "$f" "$dest/"
	done
	rm -rf "$work"
}

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

./scripts/build-love.sh >/dev/null

rm -rf dist/stock
APP="dist/stock/Roms/APPS/ValyaAdventure"
LIBS="$APP/libs"
# No saves/ or logs/ here: the launcher writes all runtime state off the SD card
# (HOME=/root/.valya) so a mid-write power-off cannot corrupt the FAT package.
mkdir -p "$APP/runtime" "$LIBS"

cp dist/valya-adventure.love "$APP/game.love"

echo "Fetching aarch64 LOVE 11.4 runtime (Cebion)..."
echo "$CEBION_FILES" | while IFS='|' read -r url sha name; do
	[ -n "$url" ] || continue
	cache="$CACHE/cebion-$name"
	fetch "$url" "$sha" "$cache"
	if [ "$name" = "love" ]; then
		cp "$cache" "$APP/runtime/love"
	else
		cp "$cache" "$LIBS/$name"
	fi
done

echo "Fetching aarch64 support libraries (Ubuntu 22.04 jammy)..."
echo "$DEB_FILES" | while IFS='|' read -r url sha; do
	[ -n "$url" ] || continue
	base=$(basename "$url")
	cache="$CACHE/$base"
	fetch "$url" "$sha" "$cache"
	extract_so "$cache" "$LIBS"
done

# Real libraries ship as libfoo.so.X.Y.Z; the runtime dlopens the SONAME
# (libfoo.so.X). Rename each to its soname rather than symlinking, because the
# SD-card Roms partition is typically FAT32/exFAT and cannot store symlinks.
( cd "$LIBS" && for real in *.so.*.*; do
	[ -f "$real" ] || continue
	soname=$(echo "$real" | sed -E 's/(\.so\.[0-9]+)\..*/\1/')
	[ "$soname" = "$real" ] && continue
	mv -f "$real" "$soname"
done )

# Launcher and docs.
cp platform/stock/ValyaAdventure.sh "dist/stock/Roms/APPS/Valya Adventure.sh"
cp platform/stock/README.md "$APP/README.md"
cp platform/stock/gamecontrollerdb.txt "$APP/gamecontrollerdb.txt"

# Executable bits: the launcher (invoked by the App Center) and the runtime.
chmod 0755 "dist/stock/Roms/APPS/Valya Adventure.sh" "$APP/runtime/love"

# Record a manifest of what shipped, with checksums, next to the package.
{
	echo "Valya Adventure stock package contents"
	echo "generated by scripts/build-stock.sh"
	echo
	echo "runtime/love (LOVE 11.4 aarch64, Cebion/love2d_aarch64, zlib)"
	echo "libs/ (bundled non-system shared libraries)"
	echo
	echo "sha256:"
	( cd "$APP" && find runtime libs -type f | LC_ALL=C sort | while IFS= read -r f; do
		echo "  $(sha256_of "$f")  $f"
	done )
} > "$APP/MANIFEST.txt"

# Package a ZIP that preserves the executable bits set above.
ZIP="dist/stock/valya-adventure-stock.zip"
rm -f "$ZIP"
( cd dist/stock && zip -X -r -q "valya-adventure-stock.zip" Roms )

echo "dist/stock"
echo "  package tree: dist/stock/Roms/APPS/"
echo "  archive:      $ZIP"
