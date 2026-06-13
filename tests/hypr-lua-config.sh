#!/bin/bash

# Regression: Ryoku ships Hyprland's compositor config as native Lua (Hyprland 0.55+)
# and every tool that touches it reads/writes Lua. This guards the whole luafication:
# the cutover invariant (Lua shipped, compositor .conf gone, hyprlock/hypridle still
# hyprlang because those tools have NO Lua config), Lua syntax validity of every
# shipped file, the entrypoint structure, the themed-border wiring, the HyprMod seed
# leaving border colors to the theme, ryoku-hypr-colors, ryoku-monitor Lua persistence,
# and the [global] migration that converts an existing hyprlang config in place.
#
# Run from any working directory; resolves repo root via BASH_SOURCE.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

HYPR="config/hypr"

fail() { echo "FAIL: $1" >&2; exit 1; }
ok() { echo "ok: $1"; }

# Syntax-check a Lua file with whatever interpreter is present (Hyprland depends on
# Lua, so one of these is normally available). Echoes nothing on success, the error
# on failure, or __NO_LUA__ if no interpreter exists (check skipped).
lua_check() {
  if command -v luac >/dev/null 2>&1; then
    luac -p "$1" 2>&1 || true
  elif command -v lua >/dev/null 2>&1; then
    lua -e "assert(loadfile([==[$1]==]))" 2>&1 || true
  elif command -v lua5.4 >/dev/null 2>&1; then
    lua5.4 -e "assert(loadfile([==[$1]==]))" 2>&1 || true
  else
    echo "__NO_LUA__"
  fi
}

assert_lua_valid() {
  local out
  out="$(lua_check "$1")"
  [[ $out == "__NO_LUA__" ]] && return 0
  [[ -z $out ]] || fail "invalid Lua in $1: $out"
}

# 1. Cutover invariant: Lua compositor shipped; compositor .conf removed; the two
#    hypr* tools that have no Lua config stay hyprlang.
for f in hyprland colors monitors keyboard gpu custom hyprland-gui; do
  [[ -f $HYPR/$f.lua ]] || fail "config/hypr/$f.lua should ship (compositor is Lua now)"
  [[ ! -e $HYPR/$f.conf ]] || fail "config/hypr/$f.conf should be gone after the Lua cutover"
done
[[ -f $HYPR/hyprlock.conf ]] || fail "hyprlock.conf must stay (hyprlock has no Lua config)"
[[ -f $HYPR/hypridle.conf ]] || fail "hypridle.conf must stay (hypridle has no Lua config)"
ok "compositor ships Lua; hyprlock/hypridle stay hyprlang"

# 2. Every shipped Lua file is syntactically valid.
parser=0
for f in "$HYPR"/*.lua; do
  out="$(lua_check "$f")"
  if [[ $out == "__NO_LUA__" ]]; then
    echo "skip: no Lua interpreter available for syntax checks"
    parser=-1
    break
  fi
  [[ -z $out ]] || fail "invalid Lua in $f: $out"
done
(( parser == -1 )) || ok "all shipped .lua files parse cleanly"

# 3. Entrypoint structure: requires every module, keeps autostart/binds/rules.
grep -q 'require("colors")' "$HYPR/hyprland.lua" || fail "hyprland.lua should require colors"
for m in monitors keyboard gpu hyprland-gui custom; do
  grep -q "require(\"$m\")" "$HYPR/hyprland.lua" || fail "hyprland.lua should require $m"
done
grep -q 'hl.on("hyprland.start"' "$HYPR/hyprland.lua" || fail "hyprland.lua should keep the autostart hook"
grep -q 'hl.bind(' "$HYPR/hyprland.lua" || fail "hyprland.lua should define keybinds"
grep -q 'hl.window_rule(' "$HYPR/hyprland.lua" || fail "hyprland.lua should define window rules"
ok "hyprland.lua structure intact (requires, autostart, binds, window rules)"

# 4. Themed border palette: hyprland.lua references the var_* globals that colors.lua
#    defines, so a theme switch (which rewrites colors.lua) recolors the border.
for v in var_primary var_tertiary var_surface_container var_outline var_shadow; do
  grep -q "$v" "$HYPR/hyprland.lua" || fail "hyprland.lua should reference $v"
  grep -qE "^$v = " "$HYPR/colors.lua" || fail "colors.lua should define $v"
done
ok "themed border palette wired (colors.lua defines var_*, hyprland.lua uses them)"

# 5. HyprMod seed must not hardcode a border color, so the theme's palette wins.
! grep -q 'active_border' "$HYPR/hyprland-gui.lua" || \
  fail "hyprland-gui.lua seed should not hardcode a border color (theme owns it)"
ok "HyprMod seed leaves the border color to the active theme"

# 6. ryoku-hypr-colors writes a valid themed colors.lua from the live M3 scheme.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/.config/hypr" "$tmp/.local/state/ryoku-shell" "$tmp/bin"
printf 'require("custom")\n' >"$tmp/.config/hypr/hyprland.lua"   # presence => Lua mode
cat >"$tmp/.local/state/ryoku-shell/scheme.json" <<'JSON'
{"colours":{"background":"101012","surface":"181a1c","surfaceContainer":"242629","primary":"AABBCC","secondary":"CCBBAA","tertiary":"BBCCDD","outline":"556677"}}
JSON
printf '#!/bin/bash\nexit 0\n' >"$tmp/bin/hyprctl"
chmod +x "$tmp/bin/hyprctl"
HOME="$tmp" XDG_CONFIG_HOME="$tmp/.config" XDG_STATE_HOME="$tmp/.local/state" \
  RYOKU_PATH="$ROOT_DIR" PATH="$ROOT_DIR/bin:$tmp/bin:/usr/bin:/bin" \
  bash bin/ryoku-hypr-colors
colors_out="$tmp/.config/hypr/colors.lua"
[[ -f $colors_out ]] || fail "ryoku-hypr-colors should write colors.lua in Lua mode"
grep -q 'var_primary = "rgb(AABBCC)"' "$colors_out" || fail "ryoku-hypr-colors should map scheme primary -> var_primary"
grep -q 'var_surface_container = "rgb(242629)"' "$colors_out" || fail "ryoku-hypr-colors should map surfaceContainer -> var_surface_container"
grep -q 'var_outline = "rgb(556677)"' "$colors_out" || fail "ryoku-hypr-colors should map outline -> var_outline"
assert_lua_valid "$colors_out"
ok "ryoku-hypr-colors writes a valid themed colors.lua from the M3 scheme"

# 7. ryoku-monitor persists the live layout as Lua (hl.monitor) in Lua mode.
mon="$(mktemp -d)"
mkdir -p "$mon/.config/hypr" "$mon/bin"
printf 'hl.env("GDK_SCALE", "1")\nrequire("custom")\n' >"$mon/.config/hypr/hyprland.lua"
cat >"$mon/bin/hyprctl" <<'EOF'
#!/bin/bash
case "$*" in
  *"monitors all -j"*) printf '%s\n' '[{"name":"eDP-1","width":1920,"height":1080,"refreshRate":60.0,"x":0,"y":0,"scale":1.0,"transform":0,"vrr":false,"mirrorOf":"none","disabled":false}]' ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$mon/bin/hyprctl"
HOME="$mon" XDG_CONFIG_HOME="$mon/.config" RYOKU_PATH="$ROOT_DIR" \
  PATH="$ROOT_DIR/bin:$mon/bin:/usr/bin:/bin" \
  bash bin/ryoku-monitor persist
mon_out="$mon/.config/hypr/monitors.lua"
[[ -f $mon_out ]] || fail "ryoku-monitor persist should write monitors.lua in Lua mode"
grep -q 'hl.monitor(' "$mon_out" || fail "monitors.lua should use hl.monitor{}"
grep -q 'output = "eDP-1"' "$mon_out" || fail "monitors.lua should persist the live output"
grep -q 'output = "", mode = "highrr"' "$mon_out" || fail "monitors.lua should keep the hotplug catch-all"
assert_lua_valid "$mon_out"
rm -rf "$mon"
ok "ryoku-monitor persist writes a valid monitors.lua (hl.monitor + catch-all)"

# 8. The [global] migration converts an existing hyprlang config in place to a
#    loadable Lua tree, preserving the .conf as a fallback. Needs the converter
#    (python-hyprland-config, a shipped dependency); skipped if unavailable.
mig="migrations/1780924172.sh"
[[ -f $mig ]] || fail "the Lua [global] migration ($mig) should exist"
if python3 -c 'import hyprland_config' 2>/dev/null; then
  mtmp="$(mktemp -d)"
  mkdir -p "$mtmp/.config/hypr"
  cat >"$mtmp/.config/hypr/hyprland.conf" <<EOF
source = $mtmp/.config/hypr/custom.conf
bind = SUPER, Q, killactive
EOF
  printf '# user overrides\n' >"$mtmp/.config/hypr/custom.conf"
  HOME="$mtmp" XDG_CONFIG_HOME="$mtmp/.config" RYOKU_PATH="$ROOT_DIR" bash "$mig" >/dev/null
  [[ -f $mtmp/.config/hypr/hyprland.lua ]] || fail "migration should produce hyprland.lua"
  [[ -f $mtmp/.config/hypr/custom.lua ]] || fail "migration should convert the sourced custom.conf"
  [[ -f $mtmp/.config/hypr/hyprland.conf ]] || fail "migration should keep the .conf as a fallback"
  assert_lua_valid "$mtmp/.config/hypr/hyprland.lua"
  # Idempotent: a second run is a no-op (hyprland.lua already present).
  HOME="$mtmp" XDG_CONFIG_HOME="$mtmp/.config" RYOKU_PATH="$ROOT_DIR" bash "$mig" >/dev/null
  rm -rf "$mtmp"
  ok "[global] migration converts hyprlang -> loadable Lua (keeps .conf, idempotent)"
else
  echo "skip: python-hyprland-config not importable; migration conversion not checked"
fi

# 9. The Chromium screen-share indicator rule must use only valid native-Lua fields.
#    Hyprland's lua window_rule rejects `no_border` (unknown field), which aborts the
#    whole config load, and `move` must be an expression table, not a string.
grep -q 'is sharing (a window|your screen)' "$HYPR/hyprland.lua" \
  || fail "hyprland.lua should keep the screen-share indicator window rule"
! grep -q 'no_border' "$HYPR/hyprland.lua" \
  || fail "hyprland.lua must not use no_border (Hyprland lua window_rule rejects it)"
ok "screen-share indicator rule present and uses valid lua fields"

echo "hypr-lua-config: ok"
