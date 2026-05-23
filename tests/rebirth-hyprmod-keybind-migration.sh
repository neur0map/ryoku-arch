#!/bin/bash

# shellcheck disable=SC2016

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

migration=$(grep -l "Add HyprMod Super Shift comma launcher" "$ROOT_DIR"/migrations/*.sh 2>/dev/null | sort -n | tail -n1 || true)
[[ -n $migration ]] || fail "missing HyprMod keybind migration"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

home_dir="$tmp_dir/home"
hypr_dir="$home_dir/.config/hypr"
hypr_conf="$hypr_dir/hyprland.conf"
mkdir -p "$hypr_dir"

cat > "$hypr_conf" <<'HYPR'
$menu = sh -lc '$HOME/.local/bin/ryoku-shell launcher'
$systemPanel = sh -lc '$HOME/.local/bin/ryoku-shell settings'
$powerMenu = sh -lc '$HOME/.local/bin/ryoku-shell session'

bind = SUPER, S, exec, $systemPanel
bind = SUPER, P, exec, $powerMenu
HYPR

HOME="$home_dir" RYOKU_PATH="$ROOT_DIR" bash "$migration" >/dev/null

grep -Fxq '$hyprlandSettings = ryoku-launch-hyprmod' "$hypr_conf" || \
  fail "migration should add the Ryoku HyprMod launcher command"
grep -Fxq 'bind = SUPER SHIFT, comma, exec, $hyprlandSettings' "$hypr_conf" || \
  fail "migration should add Super+Shift+comma HyprMod bind"

HOME="$home_dir" RYOKU_PATH="$ROOT_DIR" bash "$migration" >/dev/null

launcher_count=$(grep -Fxc '$hyprlandSettings = ryoku-launch-hyprmod' "$hypr_conf")
bind_count=$(grep -Fxc 'bind = SUPER SHIFT, comma, exec, $hyprlandSettings' "$hypr_conf")
(( launcher_count == 1 )) || fail "migration should not duplicate the HyprMod launcher command"
(( bind_count == 1 )) || fail "migration should not duplicate the Super+Shift+comma bind"

custom_home="$tmp_dir/custom-home"
custom_hypr="$custom_home/.config/hypr"
custom_conf="$custom_hypr/hyprland.conf"
mkdir -p "$custom_hypr"

cat > "$custom_conf" <<'HYPR'
$systemPanel = sh -lc '$HOME/.local/bin/ryoku-shell settings'
bind = SUPER, S, exec, $systemPanel
bind = SUPER, comma, exec, custom-tool
HYPR

HOME="$custom_home" RYOKU_PATH="$ROOT_DIR" bash "$migration" >/dev/null

grep -Fxq 'bind = SUPER, comma, exec, custom-tool' "$custom_conf" || \
  fail "migration should preserve an existing custom Super+comma bind"
grep -Fxq 'bind = SUPER SHIFT, comma, exec, $hyprlandSettings' "$custom_conf" || \
  fail "migration should add Super+Shift+comma HyprMod bind next to a custom Super+comma bind"

echo "PASS: rebirth HyprMod keybind migration repairs existing configs"
