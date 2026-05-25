#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

migration=$(grep -l "Add Super scroll workspace navigation bindings" "$ROOT_DIR"/migrations/*.sh 2>/dev/null | sort -n | tail -n1 || true)
[[ -n $migration ]] || fail "missing Super scroll workspace migration"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

home_dir="$tmp_dir/home"
hypr_dir="$home_dir/.config/hypr"
hypr_conf="$hypr_dir/hyprland.conf"
scroll_next_var="\$workspaceScrollNext = sh -lc 'exec \"\$HOME/.local/share/ryoku/bin/ryoku-cmd-hypr-workspace-scroll\" next'"
scroll_prev_var="\$workspaceScrollPrev = sh -lc 'exec \"\$HOME/.local/share/ryoku/bin/ryoku-cmd-hypr-workspace-scroll\" prev'"
scroll_down_bind="bind = SUPER, mouse_down, exec, \$workspaceScrollPrev"
scroll_up_bind="bind = SUPER, mouse_up, exec, \$workspaceScrollNext"
mkdir -p "$hypr_dir"

cat > "$hypr_conf" <<'HYPR'
bind = SUPER, Page_Down, workspace, e+1
bind = SUPER, Page_Up, workspace, e-1
bind = SUPER, mouse_down, workspace, e+1
bind = SUPER, mouse_up, workspace, e-1

bind = SUPER, H, movefocus, l
HYPR

HOME="$home_dir" RYOKU_PATH="$ROOT_DIR" bash "$migration" >/dev/null

grep -Fxq '  pass_mouse_when_bound = false' "$hypr_conf" || \
  fail "migration should consume mouse events after mouse binds trigger"
grep -Fxq '  scroll_event_delay = 0' "$hypr_conf" || \
  fail "migration should handle every scroll tick as a bind"
! grep -Fxq 'bind = SUPER, mouse_down, workspace, e+1' "$hypr_conf" || \
  fail "migration should remove the wrapping native Super+scroll down bind"
! grep -Fxq 'bind = SUPER, mouse_up, workspace, e-1' "$hypr_conf" || \
  fail "migration should remove the wrapping native Super+scroll up bind"
grep -Fxq "$scroll_next_var" "$hypr_conf" || \
  fail "migration should add non-wrapping next workspace scroll helper"
grep -Fxq "$scroll_prev_var" "$hypr_conf" || \
  fail "migration should add non-wrapping previous workspace scroll helper"
grep -Fxq "$scroll_down_bind" "$hypr_conf" || \
  fail "migration should add Super+scroll down previous workspace bind"
grep -Fxq "$scroll_up_bind" "$hypr_conf" || \
  fail "migration should add Super+scroll up next workspace bind"

HOME="$home_dir" RYOKU_PATH="$ROOT_DIR" bash "$migration" >/dev/null

down_count=$(grep -Fxc "$scroll_down_bind" "$hypr_conf")
up_count=$(grep -Fxc "$scroll_up_bind" "$hypr_conf")
pass_count=$(grep -Fxc '  pass_mouse_when_bound = false' "$hypr_conf")
delay_count=$(grep -Fxc '  scroll_event_delay = 0' "$hypr_conf")
(( down_count == 1 )) || fail "migration should not duplicate the scroll down bind"
(( up_count == 1 )) || fail "migration should not duplicate the scroll up bind"
(( pass_count == 1 )) || fail "migration should not duplicate the mouse pass-through setting"
(( delay_count == 1 )) || fail "migration should not duplicate the scroll delay setting"

echo "PASS: rebirth Hyprland scroll workspace migration repairs existing configs"
