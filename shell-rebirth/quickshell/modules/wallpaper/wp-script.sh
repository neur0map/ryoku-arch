#!/bin/bash

# CONFIG
QML_PATH="${RYOKU_REBIRTH_SHELL_DIR:-$HOME/.config/quickshell/ryoku-rebirth-shell}/modules/wallpaper/Wallpaper.qml"
SRC_DIR="$HOME/Pictures/Wallpapers"

# 1. Kill if running
if pgrep -f "quickshell.*Wallpaper.qml" >/dev/null; then
  pkill -f "quickshell.*Wallpaper.qml"
  exit 0
fi

# 2. Detect Active Wallpaper & Calculate Index
TARGET_INDEX=0
CURRENT_SRC=""

# Check current wallpaper using swww query (setwall uses swww internally)
if command -v swww >/dev/null; then
  # swww query output: "DP-1: /path/to/image.jpg ..."
  CURRENT_SRC=$(swww query 2>/dev/null | grep -o "$SRC_DIR/[^ ]*" | head -n1)
  CURRENT_SRC=$(basename "$CURRENT_SRC")
fi

if [[ -n $CURRENT_SRC && -d $SRC_DIR ]]; then
  mapfile -t wallpapers < <(find "$SRC_DIR" -maxdepth 1 -type f -printf '%f\n' | sort)
  for index in "${!wallpapers[@]}"; do
    if [[ ${wallpapers[$index]} == "$CURRENT_SRC" ]]; then
      TARGET_INDEX="$index"
      break
    fi
  done
fi

export WALLPAPER_INDEX="$TARGET_INDEX"

# 3. Launch Quickshell
quickshell -p "$QML_PATH" &

# 4. FORCE FOCUS
sleep 0.2
hyprctl dispatch focuswindow "quickshell"
