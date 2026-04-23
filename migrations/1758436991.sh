echo "Fix Disk Usage and Docker TUIs"

APP_DIR="$HOME/.local/share/applications"
ICON_DIR="$APP_DIR/icons"

# Don't use ryoku-tui-remove to preserve icons

if [[ -f $APP_DIR/Docker.desktop ]]; then
  rm "$APP_DIR/Docker.desktop"
  ryoku-tui-install "Docker" "lazydocker" tile "$ICON_DIR/Docker.png"
fi

if [[ -f $APP_DIR/"Disk Usage.desktop" ]]; then
  rm "$APP_DIR/Disk Usage.desktop" 
  ryoku-tui-install "Disk Usage" "bash -c 'dust -r; read -n 1 -s'" float "$ICON_DIR/Disk Usage.png"
fi
