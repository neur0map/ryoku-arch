#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"

  [[ -f $ROOT_DIR/$path ]] || fail "$path should exist"
}

assert_executable() {
  local path="$1"

  assert_file "$path"
  [[ -x $ROOT_DIR/$path ]] || fail "$path should be executable"
}

assert_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq "$pattern" "$ROOT_DIR/$path" || fail "$message"
}

assert_not_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  if grep -Eq "$pattern" "$ROOT_DIR/$path"; then
    fail "$message"
  fi
}

assert_contains_multiline() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  perl -0ne 'BEGIN { $pattern = shift } if (/$pattern/) { $found = 1; exit } END { exit($found ? 0 : 1) }' \
    "$pattern" "$ROOT_DIR/$path" || fail "$message"
}

assert_not_contains_multiline() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  if perl -0ne 'BEGIN { $pattern = shift } if (/$pattern/) { $found = 1; exit } END { exit($found ? 0 : 1) }' \
    "$pattern" "$ROOT_DIR/$path"; then
    fail "$message"
  fi
}

assert_json_expr() {
  local path="$1"
  local jq_expr="$2"
  local message="$3"

  jq -e "$jq_expr" "$ROOT_DIR/$path" >/dev/null || fail "$message"
}

assert_ryoku_theme() {
  assert_file "themes/ryoku/colors.toml"
  assert_file "themes/ryoku/btop.theme"
  assert_file "themes/ryoku/icons.theme"
  assert_file "themes/ryoku/vscode.json"
  assert_contains "themes/ryoku/colors.toml" 'accent = "#F25623"' \
    "Ryoku theme should use the approved orange accent"
  assert_contains "themes/ryoku/colors.toml" 'background = "#171717"' \
    "Ryoku theme should use the approved dark background"
}

assert_shell_overlay() {
  assert_executable "install/config/ryoku-shell-branding.sh"
  assert_file "default/ryoku-shell/config-overrides.json"
  assert_file "default/ryoku-shell/branding-replacements.tsv"
  assert_contains "default/ryoku-shell/config-overrides.json" '"accentColor": "#F25623"' \
    "Ryoku shell config overlay should set the Ryoku accent"
  assert_contains "default/ryoku-shell/config-overrides.json" '"ssid": "Ryoku Hotspot"' \
    "Ryoku shell config overlay should set the branded hotspot name"
  assert_contains "default/ryoku-shell/config-overrides.json" '"enableTerminal": false' \
    "Ryoku shell config overlay should leave Ryoku themes in charge of terminal colors"
  assert_contains "default/ryoku-shell/branding-replacements.tsv" 'Welcome to Ryoku' \
    "Ryoku shell replacement map should include the welcome copy"
  assert_not_contains "install/config/ryoku-shell-branding.sh" 'echo .*iNiR|printf .*iNiR' \
    "Ryoku shell overlay should not print upstream shell branding"
}

assert_topbar_frame_overlay() {
  assert_contains "install/config/ryoku-shell-branding.sh" 'apply_topbar_hug_frame_to_file\(\)' \
    "Ryoku shell overlay should define the topbar hug-frame patch"
  assert_contains "install/config/ryoku-shell-branding.sh" 'readonly property bool ryokuTopbarHugFrame: \(Config.options\?\.bar\?\.ryokuTopbarHugFrame \?\? true\)' \
    "Topbar frame patch should use the Ryoku hug-frame config marker"
  assert_contains "install/config/ryoku-shell-branding.sh" 'component RyokuTopbarHugFrame: Canvas' \
    "Topbar frame patch should use the Brain_Shell-style seamless Canvas shape"
  assert_contains "install/config/ryoku-shell-branding.sh" 'id: ryokuTopbarHugFrameCanvas' \
    "Topbar frame patch should add the Canvas frame layer"
  assert_contains "install/config/ryoku-shell-branding.sh" 'leftWidth: root.ryokuLeftNotchWidth' \
    "Topbar frame patch should size the left notch from left content"
  assert_contains "install/config/ryoku-shell-branding.sh" 'centerWidth: root.ryokuCenterNotchWidth' \
    "Topbar frame patch should size the center notch from workspace content"
  assert_contains "install/config/ryoku-shell-branding.sh" 'rightWidth: root.ryokuRightNotchWidth' \
    "Topbar frame patch should size the right notch from right content"
  assert_not_contains "install/config/ryoku-shell-branding.sh" 'leftSectionRowLayout.childrenRect.width' \
    "Topbar frame patch should not size the left notch from the full side hit zone"
  assert_not_contains "install/config/ryoku-shell-branding.sh" 'rightSectionRowLayout.childrenRect.width' \
    "Topbar frame patch should not size the right notch from the full side hit zone"
  assert_contains "install/config/ryoku-shell-branding.sh" 'ryokuLeftContentWidth' \
    "Topbar frame patch should size the left notch from kept widgets"
  assert_contains "install/config/ryoku-shell-branding.sh" 'ryokuRightContentWidth' \
    "Topbar frame patch should size the right notch from kept widgets"
  assert_contains "install/config/ryoku-shell-branding.sh" 'workspacesWidget\.visible \? workspacesWidget\.implicitWidth' \
    "Topbar frame patch should include workspaces in the right-notch content width"
  assert_contains "install/config/ryoku-shell-branding.sh" 'ryokuRightContentWidth \+ Appearance\.rounding\.screenRounding \+ ryokuNotchPadding, 150\), 480' \
    "Topbar frame patch should cap the right-notch width at 480 (raised from 360 to fit workspaces + status indicators)"
  assert_contains "install/config/ryoku-shell-branding.sh" 'id: weatherBarLoader' \
    "Topbar frame patch should measure weather as part of the right island"
  assert_contains "install/config/ryoku-shell-branding.sh" 'apply_topbar_hug_frame_to_workspaces_file' \
    "Topbar frame patch should compact the workspace island in hug-frame mode"
  assert_contains "install/config/ryoku-shell-branding.sh" 'merge_default_config_overrides' \
    "Ryoku shell overlay should expose new bar options through live defaults"
  assert_contains "install/config/ryoku-shell-branding.sh" 'ctx.arcTo' \
    "Topbar frame patch should use rounded Canvas transitions"
  assert_contains "install/config/ryoku-shell-branding.sh" 'if \(centerStart >= centerEnd\)' \
    "Topbar frame patch should guard against overlapping notch geometry"
  assert_not_contains "install/config/ryoku-shell-branding.sh" 'ShapePath|PathQuad' \
    "Topbar frame patch should not use the previous ShapePath rewrite"
  assert_contains "install/config/ryoku-shell-branding.sh" 's/root\\.ryokuThreeIslandFrame/root.ryokuTopbarHugFrame/g' \
    "Topbar frame patch should upgrade the old floating pill marker in live files"
  assert_contains "install/config/ryoku-shell-branding.sh" 'apply_topbar_hug_frame_to_file "\$SHELL_PATH/modules/bar/BarContent.qml"' \
    "Topbar frame patch should apply to the source BarContent.qml"
  assert_contains "install/config/ryoku-shell-branding.sh" 'apply_topbar_hug_frame_to_file "\$RUNTIME_SHELL_PATH/modules/bar/BarContent.qml"' \
    "Topbar frame patch should apply to the runtime BarContent.qml"
  assert_contains "install/config/ryoku-shell-branding.sh" 'apply_topbar_hug_frame_to_bar_file "\$SHELL_PATH/modules/bar/Bar.qml"' \
    "Topbar frame patch should adjust the source bar reserved height"
  assert_contains "install/config/ryoku-shell-branding.sh" 'apply_topbar_hug_frame_to_bar_file "\$RUNTIME_SHELL_PATH/modules/bar/Bar.qml"' \
    "Topbar frame patch should adjust the runtime bar reserved height"
  assert_contains "install/config/ryoku-shell-branding.sh" 'ryokuTopbarReservedHeight' \
    "Topbar frame patch should reserve less height so frame gaps show the window below"
  assert_not_contains "install/config/ryoku-shell-branding.sh" 'id: ryokuLeftTopbarGap|id: ryokuRightTopbarGap' \
    "Topbar frame patch should leave the gaps transparent instead of painting fake gap rectangles"
  assert_contains "install/config/ryoku-shell-branding.sh" 'z: 1' \
    "Topbar frame patch should paint above the shell clear layer"
  assert_contains "install/config/ryoku-shell-branding.sh" 'z: root.ryokuTopbarHugFrame \? 2 : 0' \
    "Topbar frame patch should keep widgets above the frame layer"
  assert_not_contains_multiline "install/config/ryoku-shell-branding.sh" 'apply_topbar_hug_frame_to_file[[:space:]\\]+[^[:space:]]*ScreenCorners\.qml' \
    "Topbar frame patch should not patch screen corner behavior"
  assert_contains "install/config/ryoku-shell-branding.sh" 'opacity: root.ryokuTopbarHugFrame \? 0 : 1' \
    "Topbar frame patch should keep center spacers laid out but visually hidden"
  assert_contains "install/config/ryoku-shell-branding.sh" 'visible: \(Config.options\?\.bar.borderless\) \\&\\& !root.ryokuTopbarHugFrame' \
    "Topbar frame patch should hide old borderless separators in frame gaps"
  assert_not_contains_multiline "install/config/ryoku-shell-branding.sh" 'TimerIndicator \{\n\s*visible: !root\.ryokuTopbarHugFrame\n\/s;' \
    "Topbar frame patch should no longer force-hide the timer indicator under the hug frame"
  assert_contains "install/config/ryoku-shell-branding.sh" '# Regress force-hide: TimerIndicator' \
    "Topbar frame patch should regress (remove) any previously-injected TimerIndicator force-hide line"
  assert_not_contains_multiline "install/config/ryoku-shell-branding.sh" 'ShellUpdateIndicator \{\n\s*visible: !root\.ryokuTopbarHugFrame\n\/s;' \
    "Topbar frame patch should no longer force-hide the shell update indicator under the hug frame"
  assert_contains "install/config/ryoku-shell-branding.sh" '# Regress force-hide: ShellUpdateIndicator' \
    "Topbar frame patch should regress (remove) any previously-injected ShellUpdateIndicator force-hide line"
  assert_json_expr "default/ryoku-shell/config-overrides.json" '.bar.ryokuTopbarHugFrame == true' \
    "Ryoku shell config overlay should enable the top-attached hug frame"
  assert_json_expr "default/ryoku-shell/config-overrides.json" '.bar.cornerStyle == 0' \
    "Ryoku shell config overlay should keep the bar in Hug corner mode"
  assert_json_expr "default/ryoku-shell/config-overrides.json" '.bar.showBackground == true' \
    "Ryoku shell config overlay should keep hug decorators enabled"
  assert_json_expr "default/ryoku-shell/config-overrides.json" '.bar.borderless == true' \
    "Ryoku shell config overlay should suppress BarGroup pill backgrounds"
  assert_json_expr "default/ryoku-shell/config-overrides.json" '.bar.modules.resources == false' \
    "Ryoku shell config overlay should hide resource/system monitor modules"
  assert_json_expr "default/ryoku-shell/config-overrides.json" '.bar.modules.media == false' \
    "Ryoku shell config overlay should hide the media/player module"
  assert_json_expr "default/ryoku-shell/config-overrides.json" '.bar.modules.utilButtons == false' \
    "Ryoku shell config overlay should hide quick action buttons"
  assert_json_expr "default/ryoku-shell/config-overrides.json" '.bar.modules.clock == false' \
    "Ryoku shell config overlay should hide time and date"
  assert_json_expr "default/ryoku-shell/config-overrides.json" '.bar.modules.battery == false' \
    "Ryoku shell config overlay should hide battery from the topbar"
  assert_json_expr "default/ryoku-shell/config-overrides.json" '.bar.modules.sysTray == false' \
    "Ryoku shell config overlay should hide the tray from the topbar"
  assert_json_expr "default/ryoku-shell/config-overrides.json" '.bar.modules.activeWindow == true' \
    "Ryoku shell config overlay should keep active window text"
  assert_json_expr "default/ryoku-shell/config-overrides.json" '.bar.modules.workspaces == true' \
    "Ryoku shell config overlay should keep workspace numbers"
  assert_json_expr "default/ryoku-shell/config-overrides.json" '.bar.modules.rightSidebarButton == true' \
    "Ryoku shell config overlay should keep the combined right status button"
  assert_json_expr "default/ryoku-shell/config-overrides.json" '.bar.modules.weather == true' \
    "Ryoku shell config overlay should keep weather in the right island"
}

assert_install_wiring() {
  assert_contains "install/config/theme.sh" 'ryoku-theme-set "ryoku"' \
    "Fresh install theme setup should select the shipped Ryoku theme"
  assert_not_contains "install/config/theme.sh" 'omarchy-greek-noir|HANCORE-linux|Greek Noir' \
    "Fresh install theme setup should not install the external Omarchy-derived theme"
  assert_contains "install/config/inir.sh" 'ryoku-shell-branding.sh' \
    "Shell installer should run the Ryoku branding overlay"
  assert_not_contains "install/config/inir.sh" 'missing bundled iNiR|iNiR shell' \
    "Shell installer errors should use Ryoku-facing names"
}

assert_runtime_labels() {
  assert_contains "config/systemd/user/inir.service" 'Description=Ryoku shell' \
    "User service should have a Ryoku-visible description"
  assert_not_contains "config/systemd/user/inir.service" 'iNiR|inir shell' \
    "User service should not expose upstream shell branding"
  assert_not_contains "bin/ryoku-theme-bg-set" 'iNiR|apply_inir_background' \
    "Wallpaper setter should use Ryoku-facing shell names"
  assert_not_contains "bin/ryoku-theme-bg-next" 'iNiR|apply_inir_background' \
    "Wallpaper cycler should use Ryoku-facing shell names"
  assert_not_contains "config/matugen/config.toml" 'iNiR' \
    "Matugen template comments should use Ryoku-facing names"
}

assert_credit_kept() {
  assert_contains "CREDITS.md" 'iNiR' \
    "Upstream shell credit should remain documented"
}

assert_ryoku_theme
assert_shell_overlay
assert_topbar_frame_overlay
assert_install_wiring
assert_runtime_labels
assert_credit_kept

echo "PASS: ryoku shell branding"
