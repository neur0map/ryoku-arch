echo "Move general UI/lock/scroll settings into the typed shell config"

# Stage 1 consolidation: scroll, shadow, screen-corner, scaling, lock-screen and
# navigation-keybind settings lived under the legacy settings-gui `general` domain
# with no typed equivalent. They now live in typed GlobalConfig.general
# (~/.config/ryoku/shell.json). Copy the values the user already set. The merge
# preserves typed-only siblings (logo, reverseScroll, apps/idle/battery).
src="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku/settings-gui/settings.json"
dst="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku/shell.json"

if ryoku-cmd-missing jq; then
  echo "  jq missing; skipping general config migration"
  exit 0
fi

[[ -f $src ]] || exit 0
mkdir -p "$(dirname "$dst")"
[[ -f $dst ]] || printf '{}\n' >"$dst"

tmp="$(mktemp)"
if jq --slurpfile s "$src" '
  ($s[0].general // {}) as $g
  | .general = ((.general // {})
      + ($g
         | {smoothScrollEnabled, scaleRatio, enableShadows, shadowOffsetX, shadowOffsetY,
            enableBlurBehind, screenRadiusRatio, iRadiusRatio, showScreenCorners,
            forceBlackScreenCorners, lockOnSuspend, compactLockScreen,
            showSessionButtonsOnLockScreen, enableLockScreenCountdown,
            allowPanelsOnScreenWithoutBar, showChangelogOnStartup, clockStyle,
            language, avatarImage, keybinds}
         | with_entries(select(.value != null))))
' "$dst" >"$tmp"; then
  mv "$tmp" "$dst"
else
  rm -f "$tmp"
fi

if ryoku-cmd-present systemctl; then
  systemctl --user restart ryoku-shell.service >/dev/null 2>&1 || true
fi
