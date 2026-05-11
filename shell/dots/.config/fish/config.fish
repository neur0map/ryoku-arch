if status is-interactive
  # No greeting
  set -g fish_greeting

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
