#!/bin/sh
# Valya Adventure launcher for Anbernic RG35XX Plus (H700) stock / modded-stock.
#
# Modeled on the working PortMaster-style LOVE ports for H700 stock firmware
# (jxded/anbernic-pm-launchscripts, cbepx-me StockOS-Modification):
#   - resolve our own directory from $0 (the App Center runs us from elsewhere);
#   - use the DEVICE's system SDL2 + Mali GLES (never bundle/shadow SDL2);
#   - set SDL_VIDEODRIVER=mali (the only working backend on this Mali/fbdev
#     stack; kmsdrm/fbdev/x11 are absent) and SDL_AUDIODRIVER=alsa;
#   - write ALL runtime state (saves, logs) OFF the SD-card package, so a
#     mid-write power-off cannot corrupt the FAT directory of the package;
#   - do NOT touch dmenu.bin: it exec'd us synchronously and resumes on exit.
SHDIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
APP_DIR="$SHDIR/ValyaAdventure"

# Writable area OFF the game package. Prefer internal storage that survives a
# reboot; fall back to /tmp. Never write inside APP_DIR (FAT corruption risk).
for cand in /root/.valya /mnt/mod/.valya /tmp/valya; do
	if mkdir -p "$cand" 2>/dev/null && [ -w "$cand" ]; then
		WRITEDIR="$cand"
		break
	fi
done
: "${WRITEDIR:=/tmp}"

# LOVE derives its save directory from HOME ($HOME/.local/share/love/...).
export HOME="$WRITEDIR"
LOG="$WRITEDIR/valya.log"

# Bundled non-system libs (liblove, luajit, codecs) MUST come first: the App
# Center appends its own /usr/lib to LD_LIBRARY_PATH, and the device ships a
# different LuaJIT whose ABI mismatches our liblove-11.4 (symptom: boot crash
# "SoundData.lua: table overflow"). Prepending our libs makes our matching
# LuaJIT win. We do NOT bundle SDL2, so the system's Mali-patched libSDL2
# (resolved from the loader cache) is still used for the display.
export LD_LIBRARY_PATH="$APP_DIR/libs${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# Controller mappings for the built-in buttons (harmless if SDL ignores it).
export SDL_GAMECONTROLLERCONFIG_FILE="$APP_DIR/gamecontrollerdb.txt"

# Display/audio backends for the H700 stock OS. Confirmed on-device: the only
# working SDL2 video driver is Anbernic's Mali framebuffer backend ("mali", in
# the system libSDL2 2.28.5); "kmsdrm"/"fbdev"/"x11" are absent (no X server).
# The 64-bit system PPSSPP uses this same driver. dmenu.bin owns /dev/fb0 and
# hands it to us when it exec's this script, so no driver can init EGL over SSH
# — only when launched from the App Center menu.
export SDL_VIDEODRIVER=mali
export SDL_AUDIODRIVER=alsa

# Ask the game to open fullscreen on the panel (see src/app.lua). The mali
# driver already opens at panel resolution, so this is belt-and-suspenders.
export VALE_FULLSCREEN=1

LOVE_BIN="$APP_DIR/runtime/love"

{
	echo "==== Valya Adventure launcher $(date 2>/dev/null) ===="
	echo "SHDIR=$SHDIR"
	echo "APP_DIR=$APP_DIR"
	echo "WRITEDIR=$WRITEDIR"
	echo "LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
	uname -a 2>/dev/null || true
	echo "-- system SDL2 present? --"
	ls -l /usr/lib/aarch64-linux-gnu/libSDL2-2.0.so.0* 2>/dev/null || echo "no aarch64 libSDL2 in /usr/lib/aarch64-linux-gnu"
	echo "-- Mali GLES present? --"
	ls -l /usr/lib/aarch64-linux-gnu/libEGL.so* /usr/lib/aarch64-linux-gnu/libGLESv2.so* 2>/dev/null || true
	ls -l /usr/lib/libMali.so* 2>/dev/null || true

	if [ ! -f "$LOVE_BIN" ]; then
		echo "ERROR: runtime missing at $LOVE_BIN"
		exit 127
	fi
	[ -x "$LOVE_BIN" ] || chmod 0755 "$LOVE_BIN" 2>/dev/null || true

	echo "-- launching --"
	cd "$APP_DIR" || exit 1
	"$LOVE_BIN" "$APP_DIR/game.love"
	status=$?
	echo "love exited with status $status"
	exit "$status"
} >"$LOG" 2>&1
