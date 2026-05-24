echo "Use high refresh Hyprland fallback for non-explicit monitors"

set_high_refresh_monitor_fallback() {
  local conf="$1"

  [[ -f $conf ]] || return 0

  if grep -Eq '^monitor[[:space:]]*=[[:space:]]*,[[:space:]]*preferred,[[:space:]]*auto,' "$conf"; then
    sed -i -E 's|^monitor[[:space:]]*=[[:space:]]*,[[:space:]]*preferred,[[:space:]]*auto,|monitor = , highrr, auto,|' "$conf"
  elif ! grep -Eq '^monitor[[:space:]]*=[[:space:]]*,[[:space:]]*highrr,[[:space:]]*auto,' "$conf"; then
    printf '%s\n' 'monitor = , highrr, auto, auto' >>"$conf"
  fi
}

set_high_refresh_monitor_fallback "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.conf"

if ryoku-cmd-present hyprctl; then
  hyprctl reload >/dev/null 2>&1 || true
fi
