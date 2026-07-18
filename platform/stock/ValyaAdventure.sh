#!/bin/sh
APP_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/ValyaAdventure" && pwd)"
LOG_DIR="$APP_DIR/logs"
SAVE_DIR="$APP_DIR/saves"
mkdir -p "$LOG_DIR" "$SAVE_DIR"
LOG_FILE="$LOG_DIR/startup.log"
export LD_LIBRARY_PATH="$APP_DIR/libs:$APP_DIR/runtime/lib:${LD_LIBRARY_PATH:-}"
export SDL_GAMECONTROLLERCONFIG_FILE="$APP_DIR/gamecontrollerdb.txt"
export LOVE_SAVE_DIRECTORY="$SAVE_DIR"
LOVE_BIN="$APP_DIR/runtime/love"
{
  echo "Valya Adventure stock launcher"
  echo "APP_DIR=$APP_DIR"
  date
  if [ ! -x "$LOVE_BIN" ]; then
    echo "Missing executable ARM64 LÖVE runtime at $LOVE_BIN"
    exit 127
  fi
  "$LOVE_BIN" "$APP_DIR/game.love"
} >>"$LOG_FILE" 2>&1
exit $?
