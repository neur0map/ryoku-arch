echo "De-vendor stored color-scheme + performance-mode identifiers in the settings-gui store"

# The prior migration relocated the settings-gui store to ~/.config/ryoku/settings-gui.
# De-vendor the identifiers that survive inside settings.json so an existing user's
# bar / control-center widgets and color-scheme selection keep working against the
# renamed code:
#   - widget id "NoctaliaPerformance" (bar + control-center layouts, per-widget settings)
#     -> "PerformanceMode"
#   - battery toggle key "showNoctaliaPerformance" -> "showPerformanceMode"
#   - bundled color-scheme names "Noctalia (default)" / "Noctalia-default" /
#     "Noctalia-legacy" -> "Ryoku (default)" / "ryoku-default" / "ryoku-legacy"
# Idempotent: a deep walk renames matching object keys + string values; a rerun finds
# nothing left to change. (The noctaliaPerformance -> performanceMode top-level key is
# handled by the preceding migration.)

cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
settings="$cfg/ryoku/settings-gui/settings.json"

command -v jq >/dev/null 2>&1 || exit 0
[[ -f $settings ]] || exit 0

tmp="$(mktemp)"
if jq '
  walk(
    if type == "object" then
      with_entries(.key |= (
        if . == "NoctaliaPerformance" then "PerformanceMode"
        elif . == "showNoctaliaPerformance" then "showPerformanceMode"
        else . end))
    elif type == "string" then (
      if . == "NoctaliaPerformance" then "PerformanceMode"
      elif . == "Noctalia (default)" then "Ryoku (default)"
      elif . == "Noctalia-default" then "ryoku-default"
      elif . == "Noctalia-legacy" then "ryoku-legacy"
      else . end)
    else . end)
' "$settings" >"$tmp" && [[ -s $tmp ]]; then
  mv "$tmp" "$settings"
else
  rm -f "$tmp"
fi
