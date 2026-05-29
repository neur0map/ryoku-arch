echo "Disable skwd-wall's heavy GPU wallpaper transition so the SUPER+W picker opens snappily"

# ryoku owns the wallpaper (skwd-wall runs in pickOnlyMode and routes the pick through
# `ryoku wallpaper -f`), so skwd's own transition is redundant. With its default
# `random` shader, opening the picker spawned a ~300MB GPU skwd-paper process on every
# SUPER+W, making it feel laggy/glitchy even on high-end hardware. New installs get the
# fix from config/skwd-wall/config.json; existing users are repaired here. Only users
# who have NOT configured a transition (i.e. still on the heavy default) are touched, so
# a deliberately customised transition is left alone. Idempotent and best-effort.

cfg="${XDG_CONFIG_HOME:-$HOME/.config}/skwd-wall/config.json"
[[ -f $cfg ]] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

python3 - "$cfg" <<'PY'
import json, sys
p = sys.argv[1]
try:
    with open(p) as f:
        d = json.load(f)
except Exception:
    sys.exit(0)
if "transition" in d:
    print("  skwd-wall transition already configured; leaving as-is.")
    sys.exit(0)
d["transition"] = {"enabled": False}
with open(p, "w") as f:
    json.dump(d, f, indent=2)
print("  Disabled skwd-wall transition in", p)
PY
