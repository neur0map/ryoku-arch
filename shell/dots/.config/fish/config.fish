if status is-interactive
  # No greeting
  set -g fish_greeting

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

  # Apply terminal color sequences (Material You from wallpaper)
  if test -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt
    cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
  end

  # Show the Ryoku startup logo once per terminal environment
  if command -v fastfetch >/dev/null 2>&1; and test -z "$RYOKU_FASTFETCH_SHOWN"
    set -gx RYOKU_FASTFETCH_SHOWN 1
    fastfetch
  end

  # Use starship prompt
  if command -v starship >/dev/null 2>&1
    starship init fish | source
  end

  # Aliases
  alias clear "printf '\033[2J\033[3J\033[1;1H'" # fix: kitty doesn't clear scrollback properly
  alias celar "printf '\033[2J\033[3J\033[1;1H'"
  alias claer "printf '\033[2J\033[3J\033[1;1H'"
  if command -v eza >/dev/null 2>&1
    alias ls 'eza --icons'
  end
  alias q 'qs -c ii'
end
