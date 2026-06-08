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
old_game_opacity_comment="# Keep games opaque while preserving HyprMod transparency for normal windows."
old_webapp_opacity_comment="# Keep web apps and games opaque while preserving HyprMod transparency for normal windows."
opacity_comment="# Keep web apps and games fully opaque while preserving HyprMod transparency for normal windows."
webapp_class_rule='        class = "^(chrome|chromium|google-chrome|brave|brave-browser|microsoft-edge|opera|vivaldi)-.+-Default$",'
webapp_initial_class_rule='        initial_class = "^(chrome|chromium|google-chrome|brave|brave-browser|microsoft-edge|opera|vivaldi)-.+-Default$",'
helium_class_rule='        class = "^(helium|Helium)$",'
helium_initial_class_rule='        initial_class = "^(helium|Helium)$",'
game_content_rule='        content = "game",'
game_class_rule='        class = "^(steam_app_[0-9]+|gamescope)$",'
game_initial_class_rule='        initial_class = "^(steam_app_[0-9]+|gamescope)$",'
webapp_class_opaque_rule='    opaque = true,'
helium_class_opaque_rule='    opaque = true,'
game_content_opaque_rule='    opaque = true,'
webapp_class_force_rgbx_rule='    force_rgbx = true,'
helium_class_force_rgbx_rule='    force_rgbx = true,'
game_content_force_rgbx_rule='    force_rgbx = true,'

[[ -f $ROOT_DIR/config/hypr/hyprland-gui.lua ]] || \
  fail "Ryoku should ship HyprMod's managed config target"
[[ -f $ROOT_DIR/shell/modules/controlcenter/Wrapper.qml ]] || \
  fail "missing native Ryoku settings wrapper"
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
assert_contains "$ROOT_DIR/config/hypr/hyprland.lua" \
  '^require\("hyprland-gui"\)$' \
  "Ryoku Hyprland config should source HyprMod's managed config"
assert_contains "$ROOT_DIR/config/hypr/hyprland-gui.lua" \
  '^[[:space:]]*brightness = 1\.0,$' \
  "HyprMod defaults should preserve neutral blur brightness"
assert_contains "$ROOT_DIR/config/hypr/hyprland-gui.lua" \
  '^[[:space:]]*contrast = 1\.0,$' \
  "HyprMod defaults should avoid high-contrast blur filtering"
assert_contains "$ROOT_DIR/config/hypr/hyprland-gui.lua" \
  '^[[:space:]]*vibrancy = 0\.0,$' \
  "HyprMod defaults should avoid tinting transparent content"
assert_contains "$ROOT_DIR/config/hypr/hyprland-gui.lua" \
  '^[[:space:]]*vibrancy_darkness = 0\.0,$' \
  "HyprMod defaults should avoid dark vibrancy filtering"
assert_contains "$ROOT_DIR/config/hypr/hyprland.lua" \
  '^local var_hyprlandSettings = "ryoku-launch-hyprmod"$' \
  "Ryoku Hyprland config should launch HyprMod through Ryoku geometry wrapper"
assert_contains "$ROOT_DIR/shell/modules/controlcenter/Wrapper.qml" \
  'component HyprlandPage' \
  "native settings should expose a Ryoku Hyprland page"
assert_contains "$ROOT_DIR/shell/modules/controlcenter/Wrapper.qml" \
  'ryoku-launch-hyprmod' \
  "native settings should launch HyprMod through Ryoku geometry wrapper"
rg -qU 'class = "\^\(io\.github\.bluemancz\.hyprmod\)\$",\n\s*\},\n\s*float = true' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "HyprMod should open as a floating advanced settings window"
rg -qU 'class = "\^\(io\.github\.bluemancz\.hyprmod\)\$",\n\s*\},\n\s*center = true' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "HyprMod should open centered like Ryoku settings"
assert_contains_fixed "$ROOT_DIR/config/hypr/hyprland.lua" \
  "$webapp_class_rule" \
  "Chromium web apps should stay opaque under HyprMod transparency"
assert_contains_fixed "$ROOT_DIR/config/hypr/hyprland.lua" \
  "$webapp_initial_class_rule" \
  "Chromium web apps should stay opaque when matching their initial class"
assert_contains_fixed "$ROOT_DIR/config/hypr/hyprland.lua" \
  "$helium_class_rule" \
  "Helium surfaces should stay opaque under HyprMod transparency"
assert_contains_fixed "$ROOT_DIR/config/hypr/hyprland.lua" \
  "$helium_initial_class_rule" \
  "Helium surfaces should stay opaque when matching their initial class"
assert_contains_fixed "$ROOT_DIR/config/hypr/hyprland.lua" \
  "$game_content_rule" \
  "game content should stay opaque under HyprMod transparency"
assert_contains_fixed "$ROOT_DIR/config/hypr/hyprland.lua" \
  "$game_class_rule" \
  "Steam games should stay opaque even when they do not report game content"
assert_contains_fixed "$ROOT_DIR/config/hypr/hyprland.lua" \
  "$game_initial_class_rule" \
  "Steam games should stay opaque when matching their initial class"
assert_contains_fixed "$ROOT_DIR/config/hypr/hyprland.lua" \
  "$webapp_class_opaque_rule" \
  "Chromium web apps should be forced to opaque surfaces"
assert_contains_fixed "$ROOT_DIR/config/hypr/hyprland.lua" \
  "$helium_class_opaque_rule" \
  "Helium surfaces should be forced to opaque surfaces"
assert_contains_fixed "$ROOT_DIR/config/hypr/hyprland.lua" \
  "$game_content_opaque_rule" \
  "game content should be forced to opaque surfaces"
assert_contains_fixed "$ROOT_DIR/config/hypr/hyprland.lua" \
  "$webapp_class_force_rgbx_rule" \
  "Chromium web apps should ignore alpha channels"
assert_contains_fixed "$ROOT_DIR/config/hypr/hyprland.lua" \
  "$helium_class_force_rgbx_rule" \
  "Helium surfaces should ignore alpha channels"
assert_contains_fixed "$ROOT_DIR/config/hypr/hyprland.lua" \
  "$game_content_force_rgbx_rule" \
  "game content should ignore alpha channels"
if [[ -f $ROOT_DIR/shell/modules/controlcenter/WindowTitle.qml ]] \
  && grep -Fq 'text: qsTr("Ryoku Settings")' "$ROOT_DIR/shell/modules/controlcenter/WindowTitle.qml"; then
  fail "floating settings title should not duplicate the Ryoku Settings label"
fi
if rg -qU 'class = "\^\(io\.github\.bluemancz\.hyprmod\)\$",\n\s*\},\n\s*size =' "$ROOT_DIR/config/hypr/hyprland.lua"; then
  fail "HyprMod sizing should be handled by the Ryoku launcher, not a stale window rule"
fi

migration="$ROOT_DIR/migrations/1779515727.sh"
[[ -f $migration ]] || fail "missing HyprMod persistence migration"
game_opacity_migration="$ROOT_DIR/migrations/1779597877.sh"
[[ -f $game_opacity_migration ]] || fail "missing game opacity migration"
hyprmod_blur_migration="$ROOT_DIR/migrations/1779660082.sh"
[[ -f $hyprmod_blur_migration ]] || fail "missing HyprMod blur migration"
webapp_opacity_migration="$ROOT_DIR/migrations/1779660083.sh"
[[ -f $webapp_opacity_migration ]] || fail "missing webapp opacity migration"
webapp_opacity_repair_migration="$ROOT_DIR/migrations/1779766329.sh"
[[ -f $webapp_opacity_repair_migration ]] || fail "missing webapp opacity repair migration"
assert_contains "$webapp_opacity_repair_migration" '1779660083\.sh' \
  "repair migration should re-run the webapp opacity convergence"

# The section below exercises the legacy hyprlang migrations (1779*), which still
# converge an existing .conf and emit hyprlang windowrules. Re-bind the rule needles
# to their hyprlang forms for these temp-.conf assertions; the Lua forms above are
# what the shipped hyprland.lua assertions match.
webapp_class_rule="windowrule = opacity 1.0 override 1.0 override 1.0 override, match:class ^(chrome|chromium|google-chrome|brave|brave-browser|microsoft-edge|opera|vivaldi)-.+-Default$"
webapp_initial_class_rule="windowrule = opacity 1.0 override 1.0 override 1.0 override, match:initial_class ^(chrome|chromium|google-chrome|brave|brave-browser|microsoft-edge|opera|vivaldi)-.+-Default$"
helium_class_rule="windowrule = opacity 1.0 override 1.0 override 1.0 override, match:class ^(helium|Helium)$"
helium_initial_class_rule="windowrule = opacity 1.0 override 1.0 override 1.0 override, match:initial_class ^(helium|Helium)$"
game_content_rule="windowrule = opacity 1.0 override 1.0 override 1.0 override, match:content game"
game_class_rule="windowrule = opacity 1.0 override 1.0 override 1.0 override, match:class ^(steam_app_[0-9]+|gamescope)$"
game_initial_class_rule="windowrule = opacity 1.0 override 1.0 override 1.0 override, match:initial_class ^(steam_app_[0-9]+|gamescope)$"
webapp_class_opaque_rule="windowrule = opaque true, match:class ^(chrome|chromium|google-chrome|brave|brave-browser|microsoft-edge|opera|vivaldi)-.+-Default$"
helium_class_opaque_rule="windowrule = opaque true, match:class ^(helium|Helium)$"
game_content_opaque_rule="windowrule = opaque true, match:content game"
webapp_class_force_rgbx_rule="windowrule = force_rgbx true, match:class ^(chrome|chromium|google-chrome|brave|brave-browser|microsoft-edge|opera|vivaldi)-.+-Default$"
helium_class_force_rgbx_rule="windowrule = force_rgbx true, match:class ^(helium|Helium)$"
game_content_force_rgbx_rule="windowrule = force_rgbx true, match:content game"
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
decoration:active_opacity = 0.78
decoration:blur:brightness = 0.75
decoration:blur:contrast = 1.7
decoration:blur:vibrancy = 0.2
decoration:blur:vibrancy_darkness = 0.7
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

env -u XDG_CONFIG_HOME HOME="$home_dir" RYOKU_PATH="$ROOT_DIR" bash "$hyprmod_blur_migration" >/dev/null
env -u XDG_CONFIG_HOME HOME="$home_dir" RYOKU_PATH="$ROOT_DIR" bash "$hyprmod_blur_migration" >/dev/null

grep -Fxq 'decoration:active_opacity = 0.78' "$hyprmod_conf" || \
  fail "HyprMod blur migration should preserve window transparency"
grep -Fxq 'decoration:blur:brightness = 1.0' "$hyprmod_conf" || \
  fail "HyprMod blur migration should neutralize blur brightness"
grep -Fxq 'decoration:blur:contrast = 1.0' "$hyprmod_conf" || \
  fail "HyprMod blur migration should neutralize high-contrast blur"
grep -Fxq 'decoration:blur:vibrancy = 0.0' "$hyprmod_conf" || \
  fail "HyprMod blur migration should neutralize vibrancy tint"
grep -Fxq 'decoration:blur:vibrancy_darkness = 0.0' "$hyprmod_conf" || \
  fail "HyprMod blur migration should neutralize dark vibrancy"
contrast_count=$(grep -Fxc 'decoration:blur:contrast = 1.0' "$hyprmod_conf")
(( contrast_count == 1 )) || fail "HyprMod blur migration should not duplicate contrast settings"

env -u XDG_CONFIG_HOME HOME="$home_dir" RYOKU_PATH="$ROOT_DIR" bash "$game_opacity_migration" >/dev/null
env -u XDG_CONFIG_HOME HOME="$home_dir" RYOKU_PATH="$ROOT_DIR" bash "$game_opacity_migration" >/dev/null
env -u XDG_CONFIG_HOME HOME="$home_dir" RYOKU_PATH="$ROOT_DIR" bash "$webapp_opacity_migration" >/dev/null
env -u XDG_CONFIG_HOME HOME="$home_dir" RYOKU_PATH="$ROOT_DIR" bash "$webapp_opacity_migration" >/dev/null
env -u XDG_CONFIG_HOME HOME="$home_dir" RYOKU_PATH="$ROOT_DIR" PATH="$ROOT_DIR/bin:$PATH" bash "$webapp_opacity_repair_migration" >/dev/null

source_line=$(grep -Fn "$hyprmod_source_line" "$hypr_conf" | head -n1 | cut -d: -f1)
game_line=$(grep -Fn "$game_content_rule" "$hypr_conf" | head -n1 | cut -d: -f1)
(( game_line > source_line )) || fail "game opacity rules should be applied after the HyprMod source"
comment_count=$(grep -Fxc "$opacity_comment" "$hypr_conf")
old_comment_count=$(grep -Fxc "$old_game_opacity_comment" "$hypr_conf" || true)
old_webapp_comment_count=$(grep -Fxc "$old_webapp_opacity_comment" "$hypr_conf" || true)
webapp_class_count=$(grep -Fxc "$webapp_class_rule" "$hypr_conf")
webapp_initial_class_count=$(grep -Fxc "$webapp_initial_class_rule" "$hypr_conf")
helium_class_count=$(grep -Fxc "$helium_class_rule" "$hypr_conf")
helium_initial_class_count=$(grep -Fxc "$helium_initial_class_rule" "$hypr_conf")
content_count=$(grep -Fxc "$game_content_rule" "$hypr_conf")
class_count=$(grep -Fxc "$game_class_rule" "$hypr_conf")
initial_class_count=$(grep -Fxc "$game_initial_class_rule" "$hypr_conf")
webapp_opaque_count=$(grep -Fxc "$webapp_class_opaque_rule" "$hypr_conf")
helium_opaque_count=$(grep -Fxc "$helium_class_opaque_rule" "$hypr_conf")
game_opaque_count=$(grep -Fxc "$game_content_opaque_rule" "$hypr_conf")
webapp_force_rgbx_count=$(grep -Fxc "$webapp_class_force_rgbx_rule" "$hypr_conf")
helium_force_rgbx_count=$(grep -Fxc "$helium_class_force_rgbx_rule" "$hypr_conf")
game_force_rgbx_count=$(grep -Fxc "$game_content_force_rgbx_rule" "$hypr_conf")
(( comment_count == 1 )) || fail "webapp opacity migration should add its comment exactly once"
(( old_comment_count == 0 )) || fail "webapp opacity migration should remove the old game-only comment"
(( old_webapp_comment_count == 0 )) || fail "webapp opacity migration should remove the older opacity-only comment"
(( webapp_class_count == 1 )) || fail "webapp opacity migration should add the webapp class rule exactly once"
(( webapp_initial_class_count == 1 )) || fail "webapp opacity migration should add the webapp initial class rule exactly once"
(( helium_class_count == 1 )) || fail "webapp opacity migration should add the Helium class rule exactly once"
(( helium_initial_class_count == 1 )) || fail "webapp opacity migration should add the Helium initial class rule exactly once"
(( content_count == 1 )) || fail "webapp opacity migration should keep the game content rule exactly once"
(( class_count == 1 )) || fail "webapp opacity migration should keep the game class rule exactly once"
(( initial_class_count == 1 )) || fail "webapp opacity migration should keep the game initial class rule exactly once"
(( webapp_opaque_count == 1 )) || fail "webapp opacity migration should add the webapp opaque rule exactly once"
(( helium_opaque_count == 1 )) || fail "webapp opacity migration should add the Helium opaque rule exactly once"
(( game_opaque_count == 1 )) || fail "webapp opacity migration should add the game opaque rule exactly once"
(( webapp_force_rgbx_count == 1 )) || fail "webapp opacity migration should add the webapp force_rgbx rule exactly once"
(( helium_force_rgbx_count == 1 )) || fail "webapp opacity migration should add the Helium force_rgbx rule exactly once"
(( game_force_rgbx_count == 1 )) || fail "webapp opacity migration should add the game force_rgbx rule exactly once"

absolute_home="$tmp_dir/absolute-home"
absolute_hypr="$absolute_home/.config/hypr"
absolute_conf="$absolute_hypr/hyprland.conf"
mkdir -p "$absolute_hypr"
printf 'source = %s/.config/hypr/hyprland-gui.conf\n' "$absolute_home" >"$absolute_conf"

env -u XDG_CONFIG_HOME HOME="$absolute_home" RYOKU_PATH="$ROOT_DIR" bash "$migration" >/dev/null
absolute_count=$(grep -Ec 'hyprland-gui\.conf' "$absolute_conf")
(( absolute_count == 1 )) || fail "migration should detect HyprMod's existing absolute source path"

echo "PASS: HyprMod settings persist across Hyprland reloads"
