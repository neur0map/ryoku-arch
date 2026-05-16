echo "Route Yazi text editing through Ryoku's editor launcher"

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

append_fish_editor_block() {
  local fish_config="$HOME/.config/fish/config.fish"

  [[ -f $fish_config ]] || return 0
  grep -q 'RYOKU_EDITOR' "$fish_config" && return 0

  cat >>"$fish_config" <<'EOF'

# Ryoku editor defaults for terminal tools such as Yazi.
if status is-interactive
  if not set -q RYOKU_EDITOR
    set -gx RYOKU_EDITOR nvim
  end
  if not set -q EDITOR
    set -gx EDITOR $RYOKU_EDITOR
  end
  if not set -q VISUAL
    set -gx VISUAL $EDITOR
  end
  if not set -q SUDO_EDITOR
    set -gx SUDO_EDITOR $VISUAL
  end
end
EOF
}

set_env_line "$HOME/.config/uwsm/default" RYOKU_EDITOR nvim
set_env_line "$HOME/.config/uwsm/default" EDITOR nvim
set_env_line "$HOME/.config/uwsm/default" VISUAL nvim
set_env_line "$HOME/.config/uwsm/default" SUDO_EDITOR nvim

append_fish_editor_block

if [[ -x $RYOKU_PATH/bin/ryoku-refresh-yazi-editor ]]; then
  "$RYOKU_PATH/bin/ryoku-refresh-yazi-editor" || true
fi
