echo "Install Neovim and Ryoku LazyVim defaults"

MARKER="$HOME/.local/state/ryoku/neovim-lazyvim-defaults.done"
NVIM_CONFIG_DIR="$HOME/.config/nvim"
NVIM_CONFIG_TARGET="$NVIM_CONFIG_DIR"

if [[ -f $MARKER ]]; then
  exit 0
fi

ryoku-snapshot create || true
ryoku-pkg-add neovim

select_nvim_config_target() {
  [[ -d $NVIM_CONFIG_DIR ]] || return 0
  [[ -e $NVIM_CONFIG_DIR/.ryoku-lazyvim ]] && return 0
  [[ -z $(find "$NVIM_CONFIG_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null) ]] && return 0

  NVIM_CONFIG_TARGET="$HOME/.config/nvim.ryoku-lazyvim-defaults.$(date +%s)"
  echo "  existing ~/.config/nvim preserved"
  echo "  staged Ryoku LazyVim defaults -> $NVIM_CONFIG_TARGET"
}

copy_default_nvim_file() {
  local relative_path="$1"
  local target_relative="${relative_path#nvim/}"
  local target_file="$NVIM_CONFIG_TARGET/$target_relative"

  mkdir -p "$(dirname "$target_file")"
  cp -f "$RYOKU_PATH/config/$relative_path" "$target_file"
}

refresh_nvim_file() {
  local relative_path="$1"

  case $NVIM_CONFIG_TARGET in
  "$NVIM_CONFIG_DIR")
    mkdir -p "$(dirname "$HOME/.config/$relative_path")"
    ryoku-refresh-config "$relative_path"
    ;;
  *)
    copy_default_nvim_file "$relative_path"
    ;;
  esac
}

set_env_line() {
  local file="$1" key="$2" value="$3"
  mkdir -p "$(dirname "$file")"
  touch "$file"

  if grep -q "^export $key=" "$file"; then
    sed -i "s|^export $key=.*|export $key=$value|" "$file"
  else
    printf 'export %s=%s\n' "$key" "$value" >>"$file"
  fi
}

set_mime_default() {
  local mime="$1"
  command -v xdg-mime >/dev/null 2>&1 || return 0
  xdg-mime default ryoku-editor.desktop "$mime" 2>/dev/null || true
}

seed_nvim_offline_cache() {
  local offline_cache="${RYOKU_NVIM_OFFLINE_CACHE:-/var/cache/ryoku/nvim}"
  local data_home="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"

  [[ -d $offline_cache ]] || return 0
  mkdir -p "$data_home"
  cp -an "$offline_cache/." "$data_home/" 2>/dev/null || true
}

enable_shell_neovim_theming() {
  local config_file="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku-shell/config.json"
  local temp_file

  [[ -f $config_file ]] || return 0
  ryoku-cmd-present jq || return 0

  temp_file=$(mktemp)
  jq '
    .appearance = (.appearance // {})
    | .appearance.wallpaperTheming = (.appearance.wallpaperTheming // {})
    | .appearance.wallpaperTheming.enableNeovim = true
  ' "$config_file" >"$temp_file" && mv "$temp_file" "$config_file"
}

select_nvim_config_target

refresh_nvim_file nvim/.ryoku-lazyvim
refresh_nvim_file nvim/init.lua
refresh_nvim_file nvim/lua/config/lazy.lua
refresh_nvim_file nvim/lua/config/options.lua
refresh_nvim_file nvim/lua/config/keymaps.lua
refresh_nvim_file nvim/lua/config/autocmds.lua
refresh_nvim_file nvim/lua/plugins/ryoku.lua
refresh_nvim_file nvim/lua/plugins/ryoku-dashboard.lua
refresh_nvim_file nvim/lua/plugins/99-ryoku-user.lua
seed_nvim_offline_cache
ryoku-refresh-applications

set_env_line "$HOME/.config/uwsm/default" RYOKU_EDITOR nvim
set_env_line "$HOME/.config/uwsm/default" EDITOR nvim
set_env_line "$HOME/.config/uwsm/default" VISUAL nvim
set_env_line "$HOME/.config/uwsm/default" SUDO_EDITOR nvim

for mime in \
  text/plain \
  text/english \
  text/x-makefile \
  text/x-c++hdr \
  text/x-c++src \
  text/x-chdr \
  text/x-csrc \
  text/x-java \
  text/x-moc \
  text/x-pascal \
  text/x-tcl \
  text/x-tex \
  application/x-shellscript \
  text/x-c \
  text/x-c++ \
  application/xml \
  text/xml
do
  set_mime_default "$mime"
done

enable_shell_neovim_theming

mkdir -p "$HOME/.local/state/ryoku"
touch "$MARKER"

echo "  Neovim LazyVim defaults installed"
