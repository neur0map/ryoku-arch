#!/bin/bash

SYMLINK_PATH="$HOME/.config/hypr/current_wallpaper"
VROOMIES_SHELL_DIR="${RYOKU_VROOMIES_SHELL_DIR:-$HOME/.config/quickshell/ryoku-vroomies-shell}"
SELECTED_PATH="${1:-}"

if [[ -z "$SELECTED_PATH" ]]; then
  pkill -f "quickshell.*wall.qml" || true
  QML_XHR_ALLOW_FILE_READ=1 quickshell --path "$VROOMIES_SHELL_DIR/components/wall/wall.qml" &
  exit 0
fi

[[ ! -f "$SELECTED_PATH" ]] && exit 1

ln -sf "$SELECTED_PATH" "$SYMLINK_PATH"

awww img "$SELECTED_PATH" \
    --transition-type grow \
    --transition-pos bottom-left \
    --transition-duration 1.2 \
    --transition-fps 144 \
    --transition-bezier 0.16,1,0.3,1 \
    --resize crop &

matugen image "$SELECTED_PATH" --source-color-index 0

pkill -9 quickshell || true
QML_XHR_ALLOW_FILE_READ=1 ryoku-vroomies-shell restart &

(sleep 0.2 && bash "$HOME/.config/matugen/files/change-icons.sh") &
