echo "Migrate Hyprland to its native Lua config (Hyprland 0.55+). An existing hyprlang"
echo "config is converted in place to hyprland.lua + sibling .lua modules, preserving"
echo "your customizations; the old .conf files are left untouched as a fallback. Hyprland"
echo "loads hyprland.lua on the next login. Fresh installs already ship the Lua config."

hypr_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"

# Already on Lua (fresh install, a prior HyprMod migration, or a re-run): nothing to do.
if [[ -f $hypr_dir/hyprland.lua ]]; then
  exit 0
fi

# No hyprlang entrypoint to convert: nothing to migrate.
if [[ ! -f $hypr_dir/hyprland.conf ]]; then
  exit 0
fi

# The conversion engine ships with Ryoku (python-hyprland-config). If it is not
# importable yet (e.g. packages not installed at this point in the update), defer
# and retry on a later run rather than leaving a half-converted config.
if ! python3 -c 'import hyprland_config' 2>/dev/null; then
  echo "  python-hyprland-config not available yet; deferring Lua migration."
  exit 75
fi

# Convert the whole sourced tree (.conf -> sibling .lua): colors, monitors, keyboard,
# gpu, hyprland-gui and the user-owned custom.conf are each translated to their .lua
# sibling. The converter never edits the .conf inputs (they remain as a fallback).
# A conversion error is non-fatal: roll back and leave Hyprland on its working .conf
# (hyprlang is still supported for now), so an update is never blocked.
python3 - "$hypr_dir/hyprland.conf" <<'PY'
import sys
from pathlib import Path
from hyprland_config import analyze_conversion, execute_conversion

entry = Path(sys.argv[1])
plan = analyze_conversion(entry)
result = execute_conversion(plan, overwrite=False)

if result.errors:
    for written in result.written:
        try:
            Path(written).unlink()
        except OSError:
            pass
    print("  Lua conversion hit an error; left Hyprland on its existing .conf config:")
    for err in result.errors:
        print("   ", err)
    sys.exit(0)

print(f"  Converted {len(result.written)} file(s) to Lua; Hyprland will load "
      "hyprland.lua on next login.")
if plan.unmapped:
    print(f"  Note: {len(plan.unmapped)} hyprlang line(s) had no Lua equivalent and were "
          "skipped (your .conf is kept as reference):")
    for line in plan.unmapped:
        print(f"    [{Path(line.source).name}] {line.line}")
PY
