echo "Move panel/widget UI settings into the typed shell config"

# Stage 1 consolidation: settings-panel layout mode, panel background opacity, and
# the scrollbar / tooltip / border / translucency toggles lived under the legacy
# settings-gui `ui` domain with no typed equivalent. They now live in typed
# GlobalConfig.ui (~/.config/ryoku/shell.json). Copy the values the user already
# set. The font keys of the legacy `ui` domain are intentionally left behind
# pending the font-system reconciliation.
src="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku/settings-gui/settings.json"
dst="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku/shell.json"

if ryoku-cmd-missing jq; then
  echo "  jq missing; skipping ui config migration"
  exit 0
fi

[[ -f $src ]] || exit 0
mkdir -p "$(dirname "$dst")"
[[ -f $dst ]] || printf '{}\n' >"$dst"

tmp="$(mktemp)"
if jq --slurpfile s "$src" '
  ($s[0].ui // {}) as $u
  | .ui = ((.ui // {})
      + ($u
         | {tooltipsEnabled, scrollbarAlwaysVisible, boxBorderEnabled,
            panelBackgroundOpacity, translucentWidgets, panelsAttachedToBar,
            settingsPanelMode, settingsPanelSideBarCardStyle}
         | with_entries(select(.value != null))))
' "$dst" >"$tmp"; then
  mv "$tmp" "$dst"
else
  rm -f "$tmp"
fi

if ryoku-cmd-present systemctl; then
  systemctl --user restart ryoku-shell.service >/dev/null 2>&1 || true
fi
