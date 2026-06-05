echo "Relocate the settings-gui config/cache to the ryoku namespace and rename noctaliaPerformance -> performanceMode"

# The settings UI (formerly the vendored "noctalia" shell) stored its config
# under ~/.config/noctalia and its derived cache under ~/.cache/noctalia. The
# de-vendor rename repoints both at the ryoku/settings-gui namespace. Move an
# existing user's data so their settings + cache survive, then rename the one
# renamed setting key inside the moved settings.json. Each step is idempotent and
# best-effort: only act when the source exists and the target does not, write the
# JSON edit atomically, and never fail the migration on a missing tool/dir.

cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
cache="${XDG_CACHE_HOME:-$HOME/.cache}"

# 1. Config: ~/.config/noctalia -> ~/.config/ryoku/settings-gui.
old_cfg="$cfg/noctalia"
new_cfg="$cfg/ryoku/settings-gui"
if [[ -d $old_cfg && ! -e $new_cfg ]]; then
  mkdir -p "$cfg/ryoku" || true
  mv "$old_cfg" "$new_cfg" || true
fi

# 2. Cache: ~/.cache/noctalia -> ~/.cache/ryoku/settings-gui.
old_cache="$cache/noctalia"
new_cache="$cache/ryoku/settings-gui"
if [[ -d $old_cache && ! -e $new_cache ]]; then
  mkdir -p "$cache/ryoku" || true
  mv "$old_cache" "$new_cache" || true
fi

# 3. Setting key: rename the top-level noctaliaPerformance -> performanceMode in
#    the (now relocated) settings.json. Guarded on jq + file + key presence so a
#    re-run is a no-op once the key is gone; written atomically via a temp file.
settings="$new_cfg/settings.json"
if command -v jq >/dev/null 2>&1 && [[ -f $settings ]]; then
  if jq -e 'has("noctaliaPerformance")' "$settings" >/dev/null 2>&1; then
    tmp="$(mktemp)" || exit 0
    if jq '. + {performanceMode: .noctaliaPerformance} | del(.noctaliaPerformance)' "$settings" >"$tmp" 2>/dev/null; then
      cat "$tmp" >"$settings" || true
    fi
    rm -f "$tmp"
  fi
fi
