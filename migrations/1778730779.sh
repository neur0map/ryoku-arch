echo "Refresh Ryoku Neovim dashboard tagline"

NVIM_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
DASHBOARD_FILE="$NVIM_CONFIG_DIR/lua/plugins/ryoku-dashboard.lua"
TAGLINE="               力と美のために · For the sake of power and beauty."

if [[ -f $NVIM_CONFIG_DIR/.ryoku-lazyvim ]]; then
  if [[ ! -f $DASHBOARD_FILE ]]; then
    mkdir -p "$(dirname "$DASHBOARD_FILE")"
    cp -f "$RYOKU_PATH/config/nvim/lua/plugins/ryoku-dashboard.lua" "$DASHBOARD_FILE"
  elif ! grep -Fq "$TAGLINE" "$DASHBOARD_FILE"; then
    temp_file=$(mktemp)
    awk -v tagline="$TAGLINE" '
      {
        print
        if (!inserted && $0 == "                         RYOKU") {
          print tagline
          inserted = 1
        }
      }
    ' "$DASHBOARD_FILE" >"$temp_file"
    if grep -Fq "$TAGLINE" "$temp_file"; then
      mv "$temp_file" "$DASHBOARD_FILE"
    else
      rm -f "$temp_file"
      cp -f "$RYOKU_PATH/config/nvim/lua/plugins/ryoku-dashboard.lua" "$DASHBOARD_FILE"
    fi
  fi
fi
