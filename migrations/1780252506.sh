echo "Ship the modern desktop clock style"

# The rice now pins background.desktopClock.style to "modern". Bring existing
# installs in line: set the style to modern when the user never picked one, and
# turn the clock on only when the enabled key is entirely absent. An explicit
# style or an explicit enabled:false is left untouched.
config_file="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku/shell.json"

if ryoku-cmd-missing jq; then
  echo "  jq missing; skipping desktop clock style update"
  exit 0
fi

mkdir -p "$(dirname "$config_file")"
[[ -f $config_file ]] || printf '{}\n' >"$config_file"

tmp="$(mktemp)"
if jq '
  .background = (.background // {})
  | .background.desktopClock = (.background.desktopClock // {})
  | (if (.background.desktopClock.style // "") == "" then
       .background.desktopClock.style = "modern"
     else . end)
  | (if (.background.desktopClock | has("enabled") | not) then
       .background.desktopClock.enabled = true
     else . end)
' "$config_file" >"$tmp"; then
  mv "$tmp" "$config_file"
else
  rm -f "$tmp"
fi

if ryoku-cmd-present systemctl; then
  systemctl --user restart ryoku-shell.service >/dev/null 2>&1 || true
fi
