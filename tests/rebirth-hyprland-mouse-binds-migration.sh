#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

migration=$(grep -l "Restore Hyprland mouse move and resize bindings" "$ROOT_DIR"/migrations/*.sh 2>/dev/null | sort -n | tail -n1 || true)
[[ -n $migration ]] || fail "missing Hyprland mouse bind migration"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

home_dir="$tmp_dir/home"
hypr_dir="$home_dir/.config/hypr"
hypr_conf="$hypr_dir/hyprland.conf"
mkdir -p "$hypr_dir"

cat > "$hypr_conf" <<'HYPR'
bind = SUPER, F, fullscreen,
bind = SUPER, A, togglefloating,

bind = SUPER, H, movefocus, l
HYPR

HOME="$home_dir" RYOKU_PATH="$ROOT_DIR" bash "$migration" >/dev/null

grep -Fxq 'bindmd = SUPER, mouse:272, Move window, movewindow' "$hypr_conf" || \
  fail "migration should add Super+left-drag move bind"
grep -Fxq 'bindmd = SUPER, mouse:273, Resize window, resizewindow' "$hypr_conf" || \
  fail "migration should add Super+right-drag resize bind"

HOME="$home_dir" RYOKU_PATH="$ROOT_DIR" bash "$migration" >/dev/null

move_count=$(grep -Fxc 'bindmd = SUPER, mouse:272, Move window, movewindow' "$hypr_conf")
resize_count=$(grep -Fxc 'bindmd = SUPER, mouse:273, Resize window, resizewindow' "$hypr_conf")
(( move_count == 1 )) || fail "migration should not duplicate the move bind"
(( resize_count == 1 )) || fail "migration should not duplicate the resize bind"

echo "PASS: rebirth Hyprland mouse bind migration repairs existing configs"
