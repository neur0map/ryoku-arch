echo "Activate mise/zoxide/fzf in fish and make kitty the default terminal"

# Fish configs deployed before this change only added the Ryoku command dir to
# PATH and never activated mise, so dev tools installed via `mise use -g`
# (node, python, go, ...) stayed off PATH and reported "add it to your PATH".
# Append a guarded interactive block rather than refreshing the whole file, so
# any user customizations in config.fish survive. Idempotent via the marker.
append_fish_runtime_block() {
  local fish_config="$HOME/.config/fish/config.fish"

  [[ -f $fish_config ]] || return 0
  grep -q 'mise activate fish' "$fish_config" && return 0

  cat >>"$fish_config" <<'EOF'

# Ryoku shell runtime integrations (mise/zoxide/fzf) and user-local PATH.
# Without mise activation, tools installed via `mise use -g` (node, python,
# go, ...) live in the mise data dir and fish reports them as not on PATH.
if status is-interactive
  if test -d "$HOME/.local/bin"; and not contains -- "$HOME/.local/bin" $PATH
    set -gx PATH "$HOME/.local/bin" $PATH
  end
  if not set -q BAT_THEME
    set -gx BAT_THEME ansi
  end

  if command -v mise >/dev/null 2>&1
    mise activate fish | source
  end
  if command -v zoxide >/dev/null 2>&1
    zoxide init fish | source
  end
  if command -v fzf >/dev/null 2>&1
    fzf --fish | source
  end
end
EOF

  echo "Added mise/zoxide/fzf activation to ~/.config/fish/config.fish"
}

# The shipped xdg-terminals.list put Alacritty ahead of kitty, so
# xdg-terminal-exec (and anything launching a terminal through it) opened
# Alacritty. Promote kitty to the preferred terminal while keeping any other
# entries as fallbacks. Idempotent: a no-op once kitty is already first.
ensure_kitty_default_terminal() {
  local list="$HOME/.config/xdg-terminals.list"
  local line
  local -a entries=()

  if [[ ! -f $list ]]; then
    if command -v ryoku-refresh-config >/dev/null 2>&1; then
      ryoku-refresh-config xdg-terminals.list
    else
      mkdir -p "$(dirname "$list")"
      cp -f "$RYOKU_PATH/config/xdg-terminals.list" "$list"
    fi
    return 0
  fi

  while IFS= read -r line; do
    [[ -z $line || $line == \#* ]] && continue
    entries+=("$line")
  done <"$list"

  [[ ${entries[0]:-} == "kitty.desktop" ]] && return 0

  {
    echo "# Terminal emulator preference order for xdg-terminal-exec"
    echo "# The first found and valid terminal will be used"
    echo "kitty.desktop"
    for line in "${entries[@]}"; do
      [[ $line == "kitty.desktop" ]] && continue
      echo "$line"
    done
  } >"$list"

  echo "Set kitty as the default terminal in ~/.config/xdg-terminals.list"
}

append_fish_runtime_block
ensure_kitty_default_terminal
