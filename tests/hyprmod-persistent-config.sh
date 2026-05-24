#!/bin/bash

# shellcheck disable=SC2016

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq "$pattern" "$path" || fail "$message"
}

assert_contains_fixed() {
  local path="$1"
  local needle="$2"
  local message="$3"

  grep -Fxq "$needle" "$path" || fail "$message"
}

hyprmod_source_line="source = ~/.config/hypr/hyprland-gui.conf"
game_opacity_comment="# Keep games opaque while preserving HyprMod transparency for normal windows."
game_content_rule="windowrule = opacity 1.0 override 1.0 override 1.0 override, match:content game"
game_class_rule="windowrule = opacity 1.0 override 1.0 override 1.0 override, match:class ^(steam_app_[0-9]+|gamescope)$"
game_initial_class_rule="windowrule = opacity 1.0 override 1.0 override 1.0 override, match:initial_class ^(steam_app_[0-9]+|gamescope)$"

[[ -f $ROOT_DIR/config/hypr/hyprland-gui.conf ]] || \
  fail "Ryoku should ship HyprMod's managed config target"
[[ -f $ROOT_DIR/shell/modules/controlcenter/WindowTitle.qml ]] || \
  fail "missing control center title component"
[[ -x $ROOT_DIR/bin/ryoku-launch-hyprmod ]] || \
  fail "Ryoku should ship a HyprMod launcher that matches settings geometry"
assert_contains "$ROOT_DIR/bin/ryoku-launch-hyprmod" \
  'resizewindowpixel exact' \
  "HyprMod launcher should resize the app after it maps"
assert_contains "$ROOT_DIR/bin/ryoku-launch-hyprmod" \
  'width \* 0\.8' \
  "HyprMod launcher should match Ryoku settings width ratio"
assert_contains "$ROOT_DIR/bin/ryoku-launch-hyprmod" \
  'height \* 0\.78' \
  "HyprMod launcher should match Ryoku settings height ratio"
assert_contains "$ROOT_DIR/config/hypr/hyprland.conf" \
  '^source = ~/\.config/hypr/hyprland-gui\.conf$' \
  "Ryoku Hyprland config should source HyprMod's managed config"
assert_contains "$ROOT_DIR/config/hypr/hyprland.conf" \
  '^\$hyprlandSettings = ryoku-launch-hyprmod$' \
  "Ryoku Hyprland config should launch HyprMod through Ryoku geometry wrapper"
assert_contains "$ROOT_DIR/shell/modules/controlcenter/WindowTitle.qml" \
  'text: qsTr\("Hyprland"\)' \
  "official settings should expose HyprMod as the Hyprland handoff"
assert_contains "$ROOT_DIR/shell/modules/controlcenter/WindowTitle.qml" \
  'Quickshell\.execDetached\(\["ryoku-launch-hyprmod"\]\)' \
  "advanced settings button should launch HyprMod through Ryoku geometry wrapper"
assert_contains "$ROOT_DIR/shell/modules/controlcenter/WindowTitle.qml" \
  'id: closeAfterHyprmodLaunch' \
  "advanced settings should keep a handoff timer for HyprMod launch"
assert_contains "$ROOT_DIR/shell/modules/controlcenter/WindowTitle.qml" \
  'interval: 2200' \
  "advanced settings should wait briefly before closing official settings"
assert_contains "$ROOT_DIR/shell/modules/controlcenter/WindowTitle.qml" \
  'closeAfterHyprmodLaunch\.restart\(\)' \
  "advanced settings button should close official settings after the handoff delay"
assert_contains "$ROOT_DIR/config/hypr/hyprland.conf" \
  '^windowrule = match:class \^\(io\.github\.bluemancz\.hyprmod\)\$, float true$' \
  "HyprMod should open as a floating advanced settings window"
assert_contains "$ROOT_DIR/config/hypr/hyprland.conf" \
  '^windowrule = match:class \^\(io\.github\.bluemancz\.hyprmod\)\$, center true$' \
  "HyprMod should open centered like Ryoku settings"
assert_contains_fixed "$ROOT_DIR/config/hypr/hyprland.conf" \
  "$game_content_rule" \
  "game content should stay opaque under HyprMod transparency"
assert_contains_fixed "$ROOT_DIR/config/hypr/hyprland.conf" \
  "$game_class_rule" \
  "Steam games should stay opaque even when they do not report game content"
assert_contains_fixed "$ROOT_DIR/config/hypr/hyprland.conf" \
  "$game_initial_class_rule" \
  "Steam games should stay opaque when matching their initial class"
if grep -Fq 'text: qsTr("Ryoku Settings")' "$ROOT_DIR/shell/modules/controlcenter/WindowTitle.qml"; then
  fail "floating settings title should not duplicate the Ryoku Settings label"
fi
if grep -Fq 'windowrule = match:class ^(io.github.bluemancz.hyprmod)$, size' "$ROOT_DIR/config/hypr/hyprland.conf"; then
  fail "HyprMod sizing should be handled by the Ryoku launcher, not a stale window rule"
fi

migration="$ROOT_DIR/migrations/1779515727.sh"
[[ -f $migration ]] || fail "missing HyprMod persistence migration"
game_opacity_migration="$ROOT_DIR/migrations/1779597877.sh"
[[ -f $game_opacity_migration ]] || fail "missing game opacity migration"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

home_dir="$tmp_dir/home"
hypr_dir="$home_dir/.config/hypr"
hypr_conf="$hypr_dir/hyprland.conf"
hyprmod_conf="$hypr_dir/hyprland-gui.conf"
mkdir -p "$hypr_dir"

cat >"$hypr_conf" <<'HYPR'
$hyprlandSettings = hyprmod
source = ~/.config/hypr/colors.conf
windowrule = match:class ^(io.github.bluemancz.hyprmod)$, size 80% 78%

general {
  gaps_in = 5
}
HYPR

cat >"$hyprmod_conf" <<'HYPRMOD'
# Generated by HyprMod
general:gaps_in = 2
HYPRMOD

env -u XDG_CONFIG_HOME HOME="$home_dir" RYOKU_PATH="$ROOT_DIR" bash "$migration" >/dev/null
env -u XDG_CONFIG_HOME HOME="$home_dir" RYOKU_PATH="$ROOT_DIR" bash "$migration" >/dev/null

source_count=$(grep -Fxc 'source = ~/.config/hypr/hyprland-gui.conf' "$hypr_conf")
(( source_count == 1 )) || fail "migration should add the HyprMod source exactly once"
grep -Fxq '$hyprlandSettings = ryoku-launch-hyprmod' "$hypr_conf" || \
  fail "migration should converge the HyprMod launcher command to Ryoku wrapper"
! grep -Fxq '$hyprlandSettings = hyprmod' "$hypr_conf" || \
  fail "migration should remove the old direct HyprMod launcher command"
! grep -Fq 'windowrule = match:class ^(io.github.bluemancz.hyprmod)$, size' "$hypr_conf" || \
  fail "migration should remove stale HyprMod size window rules"
float_count=$(grep -Fxc 'windowrule = match:class ^(io.github.bluemancz.hyprmod)$, float true' "$hypr_conf")
center_count=$(grep -Fxc 'windowrule = match:class ^(io.github.bluemancz.hyprmod)$, center true' "$hypr_conf")
(( float_count == 1 )) || fail "migration should add the HyprMod floating rule exactly once"
(( center_count == 1 )) || fail "migration should add the HyprMod center rule exactly once"
grep -Fxq 'general:gaps_in = 2' "$hyprmod_conf" || \
  fail "migration should preserve existing HyprMod-managed settings"

env -u XDG_CONFIG_HOME HOME="$home_dir" RYOKU_PATH="$ROOT_DIR" bash "$game_opacity_migration" >/dev/null
env -u XDG_CONFIG_HOME HOME="$home_dir" RYOKU_PATH="$ROOT_DIR" bash "$game_opacity_migration" >/dev/null

source_line=$(grep -Fn "$hyprmod_source_line" "$hypr_conf" | head -n1 | cut -d: -f1)
game_line=$(grep -Fn "$game_content_rule" "$hypr_conf" | head -n1 | cut -d: -f1)
(( game_line > source_line )) || fail "game opacity rules should be applied after the HyprMod source"
comment_count=$(grep -Fxc "$game_opacity_comment" "$hypr_conf")
content_count=$(grep -Fxc "$game_content_rule" "$hypr_conf")
class_count=$(grep -Fxc "$game_class_rule" "$hypr_conf")
initial_class_count=$(grep -Fxc "$game_initial_class_rule" "$hypr_conf")
(( comment_count == 1 )) || fail "game opacity migration should add its comment exactly once"
(( content_count == 1 )) || fail "game opacity migration should add the content rule exactly once"
(( class_count == 1 )) || fail "game opacity migration should add the class rule exactly once"
(( initial_class_count == 1 )) || fail "game opacity migration should add the initial class rule exactly once"

absolute_home="$tmp_dir/absolute-home"
absolute_hypr="$absolute_home/.config/hypr"
absolute_conf="$absolute_hypr/hyprland.conf"
mkdir -p "$absolute_hypr"
printf 'source = %s/.config/hypr/hyprland-gui.conf\n' "$absolute_home" >"$absolute_conf"

env -u XDG_CONFIG_HOME HOME="$absolute_home" RYOKU_PATH="$ROOT_DIR" bash "$migration" >/dev/null
absolute_count=$(grep -Ec 'hyprland-gui\.conf' "$absolute_conf")
(( absolute_count == 1 )) || fail "migration should detect HyprMod's existing absolute source path"

echo "PASS: HyprMod settings persist across Hyprland reloads"
