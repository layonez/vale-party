# RG35XX Plus stock-firmware scaffold

Install the generated `dist/stock/Roms/APPS` contents to the SD card `Roms/APPS` directory. This follows the observed Anbernic App Center convention where shell apps live under `Roms/APPS`.

## Unverified physical-device assumptions

- Stock firmware launches `Roms/APPS/*.sh` directly and returns to the stock launcher after the script exits.
- The device needs an ARM64/aarch64 LÖVE 11.5 executable at `ValyaAdventure/runtime/love`.
- Required shared libraries belong in `ValyaAdventure/libs` or `ValyaAdventure/runtime/lib` and are loaded via `LD_LIBRARY_PATH`.
- RG35XX Plus controller names/button mappings may need a local `gamecontrollerdb.txt` entry.
- `LOVE_SAVE_DIRECTORY` behavior must be confirmed with the selected runtime; LÖVE normally uses its own save directory.

## Validation steps

1. Copy package to SD card.
2. Add executable ARM64 LÖVE 11.5 runtime and libraries.
3. Launch from App Center.
4. Check `ValyaAdventure/logs/startup.log`.
5. Verify D-pad, A, B, Start, quit, and save persistence.
