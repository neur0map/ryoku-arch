echo "Let hypridle.service own the Hyprland idle daemon"

hyprland_conf="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.conf"
stale_rebirth_hypridle_pattern='(^|/)hypridle -c .*/hypridle-rebirth[.]conf($| )'

if [[ -f $hyprland_conf ]]; then
  sed -i '\#^exec-once = hypridle -c ~/\.config/hypr/hypridle-rebirth\.conf$#d' "$hyprland_conf"
fi

if ryoku-cmd-present systemctl; then
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  systemctl --user enable --now hypridle.service >/dev/null 2>&1 || true
fi

if ryoku-cmd-present systemctl \
  && ryoku-cmd-present pgrep \
  && ryoku-cmd-present pkill \
  && systemctl --user is-active --quiet hypridle.service >/dev/null 2>&1 \
  && pgrep -f "$stale_rebirth_hypridle_pattern" >/dev/null 2>&1; then
  pkill -f "$stale_rebirth_hypridle_pattern" >/dev/null 2>&1 || true
fi

if ryoku-cmd-present hyprctl; then
  hyprctl reload >/dev/null 2>&1 || true
fi
