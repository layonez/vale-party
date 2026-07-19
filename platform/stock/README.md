# Valya Adventure — RG35XX Plus stock-firmware package

A complete, self-contained package for the Anbernic RG35XX Plus running **stock
firmware** (Anbernic OFW). It bundles a real aarch64 LÖVE runtime and every
non-system library it needs, so it runs after a plain copy to the SD card — no
manual runtime setup.

## Install

1. Build the package: `./scripts/build-stock.sh` (from a clean checkout).
2. Copy the contents of `dist/stock/Roms/APPS/` into `Roms/APPS/` on the SD
   card (internal **TF1** or external **TF2**), or extract
   `dist/stock/valya-adventure-stock.zip` at the card root — it already contains
   the `Roms/APPS/` layout.
3. On the device, open **App Center → Apps**, pick the SD card (TF-1 / TF-2),
   and launch **Valya Adventure**.

The card's `Roms` partition is usually FAT32/exFAT, so the package contains no
symbolic links: each library is stored under its real SONAME filename.

## What's in the package

```
Roms/APPS/
  Valya Adventure.sh              launcher (App Center runs this)
  ValyaAdventure/
    game.love                     the game
    runtime/love                  aarch64 LÖVE 11.4 executable
    libs/                         bundled aarch64 shared libraries
    gamecontrollerdb.txt          SDL controller mappings
    MANIFEST.txt                  sha256 of the shipped runtime + libs
    README.md                     this file
```

At runtime the launcher writes LÖVE saves and its log **off the SD card**
(under `HOME`, default `/root/.valya`), so nothing is written back into the
package — writing into the FAT package can corrupt it.

## Runtime provenance, versions, licenses

| Component | Version | Source | License |
| --- | --- | --- | --- |
| `runtime/love`, `libs/liblove-11.4.so`, `libs/libluajit-5.1.so.2` | LÖVE 11.4 (aarch64) | [`Cebion/love2d_aarch64`](https://github.com/Cebion/love2d_aarch64) (`11.4/`), the build PortMaster uses on Allwinner H700 handhelds | LÖVE: zlib; LuaJIT: MIT |
| `libs/` codec/font libraries | Ubuntu 22.04 (jammy) arm64 | `ports.ubuntu.com` `.deb` packages | freetype: FTL/GPLv2; libpng: libpng; brotli: MIT; modplug: public domain; mpg123: LGPL-2.1; openal-soft: LGPL-2.0+; theora/vorbis/ogg: BSD-3 (Xiph) |

`build-stock.sh` pins every file by URL **and sha256**; downloads are cached
under `scripts/.cache/stock/` and re-verified on each run. `MANIFEST.txt` in the
package records the sha256 of everything shipped.

**Why LÖVE 11.4 and not 11.5:** the RG35XX Plus stock OS is Ubuntu 22.04
(glibc 2.35). Prebuilt 11.5 aarch64 `liblove` binaries require glibc 2.38 and
will not load on the device; the 11.4 runtime needs only ≤ glibc 2.29. The
desktop project targets the 11.4 API too (`conf.lua`), matching the web build.

### Libraries the package deliberately does NOT bundle

`libSDL2` and the display/audio/system backends it needs — Mali GLES/EGL, ALSA,
`libc`, `libstdc++`, `libudev`, and similar — are provided by the device. Stock
firmware ships a **Mali-patched** SDL2 (2.28.5) that can drive the panel; a
generic SDL2 has no working video driver on this hardware and cannot open a
window. The launcher only *prepends* the bundled `libs/` to `LD_LIBRARY_PATH`,
so the device's SDL2 and system libraries are still resolved.

## How the launcher works

`Valya Adventure.sh` resolves its own directory from `$0` (the App Center runs
it from an unrelated working directory), then:

- **prepends** `ValyaAdventure/libs` to `LD_LIBRARY_PATH` so our bundled LuaJIT
  loads before the device's (see troubleshooting — this prevents a boot crash);
- exports `SDL_VIDEODRIVER=mali` and `SDL_AUDIODRIVER=alsa` — the only working
  backends on this framebuffer/Mali device (no X11);
- points `SDL_GAMECONTROLLERCONFIG_FILE` at the bundled `gamecontrollerdb.txt`;
- sets `HOME` to a writable dir **off the SD card** (`/root/.valya`, falling
  back to `/mnt/mod/.valya` then `/tmp`) so LÖVE's saves and the log never write
  into the package — writing into the FAT package can corrupt it;
- sets `VALE_FULLSCREEN=1` so the game opens fullscreen on the panel;
- launches `runtime/love game.love`, logging everything to `$HOME/valya.log`,
  and returns the game's exit status so the App Center menu (`dmenu.bin`)
  resumes. It never kills `dmenu.bin`.

## Troubleshooting

Read `/root/.valya/valya.log` first (or `/mnt/mod/.valya/valya.log` /
`/tmp/valya/valya.log` if `/root` was not writable). Every launch writes a
header with the resolved paths, `LD_LIBRARY_PATH`, and the system SDL2 / Mali
GLES presence check, then the runtime's stdout/stderr.

- **`SoundData.lua:41: table overflow` at boot:** the device's LuaJIT loaded
  instead of ours (ABI mismatch with `liblove-11.4`). The launcher prepends
  `libs/` to prevent this; confirm over SSH with
  `ldd runtime/love | grep luajit` — it must resolve to the bundled copy.
- **Black flash / instant return to menu, "Could not initialize EGL":** if seen
  when launched **from the App Center**, the Mali video path failed. Confirm
  `SDL_VIDEODRIVER=mali` is exported. (Over SSH this error is expected and not a
  real failure — EGL cannot init without the menu's display session.)
- **Menu renders but buttons do nothing:** the controller GUID does not match.
  This device reports `ANBERNIC-keys`, GUID `19000000010000000100000000010000`.
  Over SSH, check `/proc/bus/input/devices`; add/adjust the matching line in
  `gamecontrollerdb.txt` (and `platform/stock/gamecontrollerdb.txt` in the repo).
- **`runtime missing` in the log:** the tree was copied incompletely or the SD
  card stripped the executable bit. Re-extract the ZIP (it preserves `+x`); the
  launcher also tries to `chmod +x` the runtime on start.

See [`../../docs/stock-firmware-packaging.md`](../../docs/stock-firmware-packaging.md)
for the full engineering rationale and the SSH debugging workflow.

## Validation status

Verified on a physical RG35XX Plus (Ubuntu 22.04, kernel 4.9.170, aarch64):
the package appears in the App Center, launches, renders the game at the panel
resolution, audio plays, the display looks correct, and the built-in buttons
(D-pad, A, B, Start) drive the game.

Not yet exhaustively verified: save/settings persistence across launches. Only
this one firmware revision is confirmed. Please record the tested firmware
version when validating others.
