#!/usr/bin/env sh
set -eu
./scripts/build-love.sh >/dev/null
rm -rf dist/stock
APP="dist/stock/Roms/APPS/ValyaAdventure"
mkdir -p "$APP/runtime" "$APP/libs" "$APP/saves" "$APP/logs"
cp dist/valya-adventure.love "$APP/game.love"
cp platform/stock/ValyaAdventure.sh "dist/stock/Roms/APPS/Valya Adventure.sh"
cp platform/stock/README.md "$APP/README.md"
touch "$APP/runtime/.place-arm64-love-11.5-here" "$APP/libs/.place-shared-libraries-here" "$APP/gamecontrollerdb.txt"
echo dist/stock
