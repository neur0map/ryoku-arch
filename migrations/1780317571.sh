echo "Fix Super+W grey-flash (skwd-paper) and heal partial wallpaper colours"

# Two wallpaper-theming fixes for existing installs:
#  1. skwd-daemon prewarms a persistent skwd-paper GL background layer on every picker
#     open whenever paper.engine==skwd-paper (it ignores pickOnlyMode and transition).
#     That layer fights ryoku's own wallpaper layer and grey-flashes Super+W. Force
#     engine=awww so the prewarm never spawns, drop any lingering skwd-paper, and restart
#     the daemon so it re-reads the engine (its startup also reaps orphan paper procs).
#  2. ryoku's wallpaper flow only regenerated scheme.json (Material-3 roles); the ambxst
#     named accents + external-app theme files (~/.cache/ambxst/colors.json) were never
#     produced, so part of the shell never followed the wallpaper. Generate it now from
#     the current wallpaper so it heals without needing a wallpaper switch.

shell_state="${XDG_STATE_HOME:-$HOME/.local/state}/ryoku-shell"
wp_state="$shell_state/wallpaper"
skwd_config="${XDG_CONFIG_HOME:-$HOME/.config}/skwd-wall/config.json"
matugen_cfg="$RYOKU_PATH/shell/ambxst/assets/matugen/config.toml"

# 1a. Force skwd off the skwd-paper prewarm engine (idempotent).
if [[ -f $skwd_config ]] && command -v jq >/dev/null 2>&1; then
  if [[ "$(jq -r '.paper.engine // ""' "$skwd_config" 2>/dev/null)" != "awww" ]]; then
    tmp="$(mktemp)"
    if jq '.paper.engine = "awww"' "$skwd_config" >"$tmp" && [[ -s $tmp ]]; then
      mv "$tmp" "$skwd_config"
    else
      rm -f "$tmp"
    fi
  fi
fi

# 1b. Clear any lingering prewarmed layer and restart the daemon so it picks up engine=awww.
pkill -x skwd-paper 2>/dev/null || true
pkill -x skwd-paper-still 2>/dev/null || true
if command -v systemctl >/dev/null 2>&1; then
  systemctl --user restart skwd-daemon.service >/dev/null 2>&1 || true
fi

# 2. Generate the ambxst named-accent palette from the current wallpaper right now.
if [[ -s $wp_state/path.txt ]] && command -v matugen >/dev/null 2>&1 && [[ -f $matugen_cfg ]]; then
  src="$(head -n1 "$wp_state/path.txt")"
  poster="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku/current/background"
  if [[ "$(head -n1 "$wp_state/type.txt" 2>/dev/null)" != "image" && -e $poster ]]; then
    src="$(readlink -f "$poster")"
  fi
  mode="$(jq -r '.mode // "dark"' "$shell_state/scheme.json" 2>/dev/null || echo dark)"
  [[ $mode == "light" || $mode == "dark" ]] || mode="dark"
  if [[ -n $src && -f $src ]]; then
    matugen image "$src" --source-color-index 0 -c "$matugen_cfg" -t scheme-tonal-spot --mode "$mode" >/dev/null 2>&1 || true
  fi
fi
