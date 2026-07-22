# Stock-firmware packaging (Anbernic RG35XX Plus / H700)

How `./scripts/build-stock.sh` produces a package that boots on the Anbernic
RG35XX Plus, and *why* every non-obvious choice is the way it is. This exists so
we never have to re-derive it — it was reverse-engineered from the physical
device over SSH. If you change the runtime, the launcher, or the library set,
read this first.

The build produces `dist/stock/Roms/APPS/` (a `Valya Adventure.sh` launcher plus
a `ValyaAdventure/` payload) and a `valya-adventure-stock.zip`. End-user install
and troubleshooting live in [`../platform/stock/README.md`](../platform/stock/README.md);
this doc is the engineering rationale.

## The target device (verified on hardware)

- **SoC / GPU:** Allwinner H700, quad Cortex-A53 **aarch64**, Mali-G31 GPU.
- **OS:** **Ubuntu 22.04 LTS**, **glibc 2.35**, kernel **4.9.170** (Allwinner
  BSP), systemd. Hostname `ANBERNIC`. This is the single most important fact —
  it fixes the ABI everything else must match.
- **Display:** legacy **framebuffer** (`/dev/fb0` + `/dev/mali0`). **There is no
  X11 and no Wayland.** The system SDL2 (2.28.5, Mali-patched, at
  `/usr/lib/aarch64-linux-gnu/libSDL2-2.0.so.0.2800.5`) exposes exactly three
  video drivers: `mali`, `dummy`, `offscreen`. `kmsdrm`/`fbdev`/`x11` are
  absent.
- **GLES:** ARM Mali userspace blob; `libEGL`/`libGLESv2` in
  `/usr/lib/aarch64-linux-gnu` resolve to it.
- **Input:** the built-in buttons are one device named **`ANBERNIC-keys`**,
  handlers `kbd js0 event1` — i.e. exposed as joystick `js0`. Its SDL GUID is
  **`19000000010000000100000000010000`** (bus `0x0019`, vendor `0x0001`,
  product `0x0001`, version `0x0100`). Buttons emit `BTN_SOUTH`/`BTN_EAST`/…
- **Launcher:** the on-screen menu is `dmenu.bin`. It **owns `/dev/fb0` and
  `/dev/mali0`**, `exec`s an app's `.sh` **synchronously**, and resumes when the
  script exits. So a launched app inherits the framebuffer, and **we must never
  kill `dmenu.bin`** — doing so breaks the return-to-menu flow.
- **Card:** the SD `Roms` partition is **FAT32** (`/dev/mmcblk0p1`, mounted
  `/mnt/mmc` on device). FAT cannot store symlinks.

## Runtime & library sourcing

**LÖVE 11.4, not 11.5 — this is an ABI hard limit, not a preference.** Prebuilt
aarch64 `liblove-11.5.so` (Arch Linux ARM) requires **glibc 2.38**; the device
has **2.35**, so 11.5 will not load. The 11.4 runtime from
[`Cebion/love2d_aarch64`](https://github.com/Cebion/love2d_aarch64) needs only
≤ glibc 2.29 and is the build PortMaster uses on H700 handhelds. `conf.lua` and
the love.js web build are therefore pinned to **11.4** as well, so all three
targets share one API version.

**Bundled** (`ValyaAdventure/libs/`):

- From Cebion 11.4: `love` (→ `runtime/love`), `liblove-11.4.so`,
  `libluajit-5.1.so.2`.
- From **Ubuntu 22.04 jammy arm64 `.deb`s** (exact device-ABI match, all
  ≤ glibc 2.34): freetype (+ its `libpng16`, `libbrotli*` deps), modplug,
  mpg123, openal, theora (dec/enc), vorbis(file), ogg.

**Deliberately NOT bundled — provided by the device:** `libSDL2` and its
display/audio/system backends (Mali GLES, ALSA, `libc`, `libstdc++`, `libudev`,
…). The device's SDL2 is the **Mali-patched** build that can actually drive the
panel; a generic jammy SDL2 has no `mali` driver and cannot create a window.
This mirrors how PortMaster/PPSSPP ship on this device.

Reproducibility: `build-stock.sh` pins every download by URL **and sha256**,
caches under `scripts/.cache/stock/`, re-verifies the checksum each run
(tampering aborts the build), and writes a `MANIFEST.txt` of shipped hashes.
`.deb`s are unpacked with `ar` + `tar` (bsdtar/GNU tar both decompress
`data.tar.zst`), so no `dpkg` is needed — the build runs on macOS and Linux CI.

**FAT-safe:** libraries ship under their real SONAME filename
(`libfoo.so.6`), not as `libfoo.so.6.18.1` + symlink, because the FAT card
cannot store symlinks. The runtime `dlopen`s the soname directly.

## The launch recipe (the bugs and their fixes)

Getting from "package copied" to "game playable" meant fixing three distinct,
sequential launch failures, plus one integrity bug. Each is now encoded in
`platform/stock/ValyaAdventure.sh`.

1. **Instant exit / black flash → menu.** The device has no X11; SDL's only
   real video backend is `mali`. **Fix:** the launcher exports
   `SDL_VIDEODRIVER=mali` and `SDL_AUDIODRIVER=alsa` (the same env the device's
   64-bit PPSSPP uses).

2. **Boot crash `[love "SoundData.lua"]:41: table overflow`.** The App Center
   **appends** its own `/usr/lib` to `LD_LIBRARY_PATH`, so the **device's**
   LuaJIT loaded before our bundled one — and its ABI mismatches our
   `liblove-11.4`. **Fix:** the launcher **prepends** `ValyaAdventure/libs` so
   our matching LuaJIT wins. (We still don't bundle SDL2, so the system's
   Mali-patched `libSDL2` is still resolved from the loader cache.)

3. **Menu renders but no button does anything.** SDL saw the joystick but,
   without a matching mapping, `isGamepad()` was false, so LÖVE/Baton's
   `button:`/`axis:` bindings received nothing. The original bundled GUID was a
   guess. **Fix:** ship the **exact** `ANBERNIC-keys` mapping the H700 port
   ecosystem uses (lifted from the device's own PortMaster/PPSSPP
   `gamecontrollerdb.txt`) — see `platform/stock/gamecontrollerdb.txt`.

Plus one integrity bug found along the way:

4. **FAT directory corruption of the package.** An earlier launcher wrote
   saves/logs *inside* the package dir on the FAT card; an unclean removal left
   corrupt entries (`fsck`: "starts with free cluster"). **Fix:** the launcher
   writes **all** runtime state off the package — `HOME=/root/.valya` (falls
   back to `/mnt/mod/.valya`, then `/tmp`). LÖVE saves land in
   `$HOME/.local/share/love/…`; the launcher log is `$HOME/valya.log`.

Also correct and worth keeping: the launcher resolves its own dir from `$0`
(the App Center runs it from an unrelated CWD), exports `VALE_FULLSCREEN=1` so
`src/app.lua` opens fullscreen on the panel (belt-and-suspenders — the `mali`
driver already opens at panel resolution), and does **not** touch `dmenu.bin`.

## Debugging on the device over SSH

The device runs an SSH server (enable via the `SSH_Server.sh` App Center app;
Wi-Fi on; login `root` / `root`). From macOS, `sshpass -p root ssh root@<ip>`
works; the SSH server can rate-limit rapid reconnects, so pause between attempts.

### Finding the device on the network

Fastest: the stock firmware advertises itself over mDNS, so try the name first —
no scanning needed:

```sh
ping -c1 anbernic.local                 # resolves to the current IP
sshpass -p root ssh root@anbernic.local
```

If the name doesn't resolve, discover the IP directly:

```sh
# 1) mDNS lookup of just the address (no ping needed)
dns-sd -Gv4 anbernic.local        # prints the IP; Ctrl-C when it appears

# 2) fallback: TCP-scan the subnet for its SSH banner (no nmap needed).
#    The Anbernic answers "SSH-2.0-OpenSSH_8.9p1 Ubuntu"; other hosts differ.
net=$(ipconfig getifaddr en0 | sed 's/\.[0-9]*$//')      # e.g. 192.168.178
seq 1 254 | xargs -P50 -I{} sh -c "nc -z -G2 $net.{} 22 2>/dev/null && echo $net.{}" \
  | while read ip; do echo "$ip $(nc -w2 $ip 22 </dev/null 2>/dev/null | head -1)"; done
```

**Gotcha — Wi-Fi client isolation.** If `anbernic.local` resolves (mDNS is
multicast and the AP relays it) but `ssh`/`nc`/`ping` all fail and `arp -n <ip>`
shows `(incomplete)`, the router is blocking client-to-client unicast (AP /
"client isolation", common on guest networks). The device is fine; the LAN path
is not. Fix on the router: disable AP/client isolation, or put the Mac and the
device on the same non-guest SSID. Sync over SSH is impossible until then — fall
back to copying the package onto the SD card directly.

**SSH cannot test the display.** EGL will not initialize from an SSH session —
there is no console/session to bind to. This is not our bug: the *known-working*
PPSSPP also fails EGL over SSH and only survives by falling back to Vulkan
(which LÖVE has no equivalent for). **Rendering must be tested by launching from
the App Center menu.** Use SSH for everything else:

- read `/root/.valya/valya.log` after a menu launch (the real error);
- `ldd runtime/love` to confirm which `liblove`/`luajit`/`libSDL2` resolve;
- `evtest /dev/input/event1` and `/proc/bus/input/devices` for input/GUID;
- inspect the device's own `gamecontrollerdb.txt`
  (`/roms/ports/PortMaster/`, `/mnt/vendor/deep/ppsspp/assets/`);
- install a fixed file without re-copying the whole card:
  `mount -o remount,rw /mnt/mmc` then copy into `/mnt/mmc/Roms/APPS/…`.

## Still unverified

- Save/settings persistence across launches (writes now go to `/root/.valya`).
- Only one firmware revision (the unit tested, Ubuntu 22.04 / kernel 4.9.170)
  is confirmed. The `exdial` app set targets stock OFW `1.1.5–1.2.4`.

Confirmed on hardware: launches from the App Center, renders the game, input
(D-pad, A, B, Start) works, audio plays, and the display looks correct at the
panel resolution.
