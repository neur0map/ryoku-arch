echo "Move calendar display settings into the typed shell config"

# Stage 1 consolidation: calendar display options (week numbers, events, weather row,
# analogue clock, first day of week) lived under the legacy settings-gui `location`
# domain but are calendar settings; they now live in typed GlobalConfig.calendar
# (~/.config/ryoku/shell.json). Copy the values the user already set.
src="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku/settings-gui/settings.json"
dst="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku/shell.json"

if ryoku-cmd-missing jq; then
  echo "  jq missing; skipping calendar config migration"
  exit 0
fi

[[ -f $src ]] || exit 0
mkdir -p "$(dirname "$dst")"
[[ -f $dst ]] || printf '{}\n' >"$dst"

tmp="$(mktemp)"
if jq --slurpfile s "$src" '
  ($s[0].location // {}) as $l
  | .calendar = ((.calendar // {})
      + ($l
         | {showWeekNumberInCalendar, showCalendarEvents, showCalendarWeather, analogClockInCalendar, firstDayOfWeek}
         | with_entries(select(.value != null))))
' "$dst" >"$tmp"; then
  mv "$tmp" "$dst"
else
  rm -f "$tmp"
fi

if ryoku-cmd-present systemctl; then
  systemctl --user restart ryoku-shell.service >/dev/null 2>&1 || true
fi
