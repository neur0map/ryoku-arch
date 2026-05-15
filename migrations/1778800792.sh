echo "Add firewall tab to right-sidebar enabledWidgets"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CFG="$CONFIG_HOME/ryoku-shell/config.json"

if [[ ! -f $CFG ]]; then
  echo "  no config at $CFG, skipping"
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "  jq not available, skipping" >&2
  exit 0
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

jq '
  if (.sidebar.right.enabledWidgets // null) == null then
    .
  elif (.sidebar.right.enabledWidgets | index("firewall")) then
    .
  else
    .sidebar.right.enabledWidgets += ["firewall"]
  end
' "$CFG" > "$TMP"

if ! cmp -s "$CFG" "$TMP"; then
  cp "$TMP" "$CFG"
  echo "  appended firewall to enabledWidgets in $CFG"
else
  echo "  no change needed (key missing or already contains firewall)"
fi
