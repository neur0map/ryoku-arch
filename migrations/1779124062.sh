echo "Move Steam wallpaper theming to Millennium"

config_file="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku-shell/config.json"

if [[ -f $config_file ]]; then
  python3 - "$config_file" <<'PY'
import json
import os
import sys

path = sys.argv[1]
old_key = "enable" + "Adw" + "Steam"

try:
    with open(path) as f:
        data = json.load(f)
except Exception:
    sys.exit(0)

node = data.setdefault("appearance", {}).setdefault("wallpaperTheming", {})
if "enableSteam" not in node:
    node["enableSteam"] = bool(node.get(old_key, False))
node.pop(old_key, None)

tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
os.replace(tmp, path)
PY
fi

if [[ -x $RYOKU_PATH/shell/scripts/colors/modules/70-steam.sh ]]; then
  RYOKU_STEAM_THEME_FORCE=1 "$RYOKU_PATH/shell/scripts/colors/modules/70-steam.sh" >/dev/null 2>&1 || true
fi
