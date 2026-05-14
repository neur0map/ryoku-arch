echo "Repair Ryoku Neovim local colorscheme"

NVIM_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
NVIM_PLUGIN_DIR="$NVIM_CONFIG_DIR/lua/plugins"
NVIM_THEME_FILE="$NVIM_PLUGIN_DIR/neovim.lua"
PALETTE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated/palette.json"
TERMINAL_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated/terminal.json"
THEMEGEN="$RYOKU_PATH/shell/scripts/colors/neovim_themegen.sh"

if [[ -f $NVIM_THEME_FILE ]] && grep -Fq '"yukazakiri/ryoku.nvim"' "$NVIM_THEME_FILE"; then
  if [[ -f $PALETTE_FILE && -f $TERMINAL_FILE && -f $THEMEGEN ]]; then
    bash "$THEMEGEN" "$PALETTE_FILE" "$TERMINAL_FILE" "$NVIM_PLUGIN_DIR"
  else
    rm -f "$NVIM_THEME_FILE"
  fi
fi

if [[ -f $NVIM_CONFIG_DIR/.ryoku-lazyvim ]] \
  && [[ -f $NVIM_CONFIG_DIR/lua/config/keymaps.lua ]] \
  && grep -Fq 'ryoku.nvim' "$NVIM_CONFIG_DIR/lua/config/keymaps.lua"; then
  if command -v ryoku-refresh-config >/dev/null 2>&1; then
    ryoku-refresh-config nvim/lua/config/keymaps.lua
  else
    mkdir -p "$NVIM_CONFIG_DIR/lua/config"
    cp -f "$RYOKU_PATH/config/nvim/lua/config/keymaps.lua" "$NVIM_CONFIG_DIR/lua/config/keymaps.lua"
  fi
fi

rm -rf "$HOME/.local/share/nvim/lazy/ryoku.nvim" \
  "$HOME/.local/share/nvim/lazy/ryoku.nvim.git"
