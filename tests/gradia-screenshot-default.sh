#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"

  [[ -f $path ]] || fail "$path should exist"
}

assert_executable() {
  local path="$1"

  assert_file "$path"
  [[ -x $path ]] || fail "$path should be executable"
}

assert_contains() {
  local path="$1"
  local needle="$2"
  local message="$3"

  grep -Fq "$needle" "$path" || fail "$message"
}

assert_not_contains() {
  local path="$1"
  local needle="$2"
  local message="$3"

  if grep -Fq "$needle" "$path"; then
    fail "$message"
  fi
}

assert_executable bin/ryoku-cmd-screenshot
bash -n bin/ryoku-cmd-screenshot || fail "screenshot helper should have valid bash syntax"

# shellcheck disable=SC2016
assert_contains config/hypr/hyprland.lua 'local var_screenshot = "sh -lc '\''exec \"$HOME/.local/share/ryoku/bin/ryoku-cmd-screenshot\" screen'\''"' \
  "Print should use the installed Ryoku screenshot helper"
# shellcheck disable=SC2016
assert_contains config/hypr/hyprland.lua 'local var_regionScreenshot = "sh -lc '\''exec \"$HOME/.local/share/ryoku/bin/ryoku-cmd-screenshot\" region'\''"' \
  "Region screenshot binds should use the installed Ryoku screenshot helper"
# shellcheck disable=SC2016
assert_contains config/hypr/hyprland.lua 'local var_screenshotChooser = "sh -lc '\''exec \"$HOME/.local/share/ryoku/bin/ryoku-cmd-screenshot\" choose'\''"' \
  "Super+S should use the installed Ryoku screenshot chooser"
# shellcheck disable=SC2016
assert_contains config/hypr/hyprland.lua 'hl.bind("Print", hl.dsp.exec_cmd(var_screenshot))' \
  "Print should be bound to the screenshot helper"
# shellcheck disable=SC2016
assert_contains config/hypr/hyprland.lua 'hl.bind("SHIFT + Print", hl.dsp.exec_cmd(var_regionScreenshot))' \
  "Shift+Print should be bound to the region screenshot helper"
# shellcheck disable=SC2016
assert_contains config/hypr/hyprland.lua 'hl.bind("SUPER + S", hl.dsp.exec_cmd(var_screenshotChooser))' \
  "Super+S should be bound to the screenshot chooser"
# shellcheck disable=SC2016
assert_not_contains config/hypr/hyprland.lua 'hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd(var_screenshotChooser))' \
  "Super+Shift+S should not be the screenshot chooser bind"

assert_contains shell/modules/areapicker/Picker.qml 'wl-copy --type image/png < ' \
  "Shell screenshot picker should copy saved screenshots"
assert_contains shell/modules/areapicker/Picker.qml '"ryoku-cmd-image-edit", path' \
  "Shell screenshot picker should open saved screenshots with the Ryoku image editor"
assert_not_contains shell/modules/areapicker/Picker.qml 'swappy' \
  "Gradia should replace swappy as the default screenshot editor"
assert_not_contains install/ryoku-base.packages 'swappy' \
  "Swappy should not ship now that Gradia is the screenshot editor"
assert_not_contains install/ryoku-base.packages 'satty' \
  "Satty should not ship now that Gradia is the screenshot editor"
assert_not_contains install/ryoku-aur.packages 'swappy' \
  "Swappy should not ship from the AUR manifest"
assert_not_contains install/ryoku-aur.packages 'satty' \
  "Satty should not ship from the AUR manifest"
assert_contains install/ryoku-aur.packages 'gradia' \
  "Fresh ISO installs should include Gradia"
assert_contains install/ryoku-base.packages 'xdg-desktop-portal' \
  "Fresh ISO installs should include the desktop portal service"
assert_contains install/ryoku-base.packages 'xdg-desktop-portal-hyprland' \
  "Fresh ISO installs should include the Hyprland portal backend"

assert_contains migrations/1779556929.sh 'screenshot_line=' \
  "Migration should route Print through the screenshot helper"
assert_contains migrations/1779556929.sh 'region_screenshot_line=' \
  "Migration should route region screenshot binds through the screenshot helper"
assert_contains migrations/1779556929.sh 'screenshot_chooser_line=' \
  "Migration should route Super+S through the screenshot chooser"
assert_contains migrations/1779556929.sh '$HOME/.local/share/ryoku/bin/ryoku-cmd-screenshot' \
  "Migration should use the installed helper path so Hyprland can execute it"
# shellcheck disable=SC2016
assert_contains migrations/1779556929.sh 'bind = SUPER, S, exec, \$screenshotChooser' \
  "Migration should bind Super+S to the screenshot chooser"
assert_contains migrations/1779556929.sh 'for package in swappy satty; do' \
  "Migration should check old screenshot editors"
# shellcheck disable=SC2016
assert_contains migrations/1779556929.sh 'ryoku-pkg-remove "${old_screenshot_apps[@]}"' \
  "Migration should remove old screenshot editors"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/bin" "$tmp_dir/screens"

cat >"$tmp_dir/bin/grim" <<'SH'
#!/bin/bash
set -euo pipefail

if [[ ${1:-} == "-g" ]]; then
  printf 'grim region %s %s\n' "$2" "$3" >>"$RYOKU_TEST_LOG"
  printf 'region image\n' >"$3"
else
  printf 'grim screen %s\n' "$1" >>"$RYOKU_TEST_LOG"
  printf 'screen image\n' >"$1"
fi
SH

cat >"$tmp_dir/bin/slurp" <<'SH'
#!/bin/bash
set -euo pipefail
printf '12,34 56x78\n'
SH

cat >"$tmp_dir/bin/wl-copy" <<'SH'
#!/bin/bash
set -euo pipefail
printf 'wl-copy %s\n' "$*" >>"$RYOKU_TEST_LOG"
cat >"$RYOKU_TEST_CLIPBOARD"
SH

cat >"$tmp_dir/bin/editor" <<'SH'
#!/bin/bash
set -euo pipefail
printf 'editor %s\n' "$1" >>"$RYOKU_TEST_LOG"
SH

cat >"$tmp_dir/bin/gradia" <<'SH'
#!/bin/bash
set -euo pipefail
printf 'gradia %s\n' "$*" >>"$RYOKU_TEST_LOG"
SH

cat >"$tmp_dir/bin/ryoku-shell" <<'SH'
#!/bin/bash
set -euo pipefail
printf 'ryoku-shell %s\n' "$*" >>"$RYOKU_TEST_LOG"
SH

cat >"$tmp_dir/bin/fuzzel" <<'SH'
#!/bin/bash
set -euo pipefail
printf 'menu %s\n' "$*" >>"$RYOKU_TEST_LOG"
cat >"$RYOKU_TEST_MENU_OPTIONS"
printf '%s\n' "${RYOKU_TEST_CHOICE:-}"
SH

cat >"$tmp_dir/bin/systemctl" <<'SH'
#!/bin/bash
set -euo pipefail
printf 'systemctl %s\n' "$*" >>"$RYOKU_TEST_LOG"
SH

cat >"$tmp_dir/bin/notify-send" <<'SH'
#!/bin/bash
exit 0
SH

chmod +x "$tmp_dir/bin/"*

run_gradia_helper() {
  local mode="$1"

  : >"$tmp_dir/log"
  PATH="$tmp_dir/bin:$PATH" \
  RYOKU_TEST_LOG="$tmp_dir/log" \
  RYOKU_SCREENSHOT_GRADIA="$tmp_dir/bin/gradia" \
  RYOKU_SCREENSHOT_SYSTEMCTL="$tmp_dir/bin/systemctl" \
    bash bin/ryoku-cmd-screenshot "$mode" >/dev/null
}

run_shell_helper() {
  local mode="$1"

  : >"$tmp_dir/log"
  PATH="$tmp_dir/bin:$PATH" \
  RYOKU_TEST_LOG="$tmp_dir/log" \
  RYOKU_SCREENSHOT_SHELL="$tmp_dir/bin/ryoku-shell" \
  RYOKU_SCREENSHOT_GRADIA="$tmp_dir/bin/gradia" \
    bash bin/ryoku-cmd-screenshot "$mode" >/dev/null
}

run_fallback_helper() {
  local mode="$1"
  local choice="${2:-}"

  : >"$tmp_dir/log"
  : >"$tmp_dir/clipboard"
  : >"$tmp_dir/menu-options"
  PATH="$tmp_dir/bin:$PATH" \
  RYOKU_TEST_LOG="$tmp_dir/log" \
  RYOKU_TEST_CLIPBOARD="$tmp_dir/clipboard" \
  RYOKU_TEST_MENU_OPTIONS="$tmp_dir/menu-options" \
  RYOKU_TEST_CHOICE="$choice" \
  RYOKU_SCREENSHOT_DIR="$tmp_dir/screens" \
  RYOKU_SCREENSHOT_GRIM="$tmp_dir/bin/grim" \
  RYOKU_SCREENSHOT_SLURP="$tmp_dir/bin/slurp" \
  RYOKU_SCREENSHOT_WL_COPY="$tmp_dir/bin/wl-copy" \
  RYOKU_SCREENSHOT_EDITOR="$tmp_dir/bin/editor" \
  RYOKU_SCREENSHOT_MENU="$tmp_dir/bin/fuzzel" \
  RYOKU_SCREENSHOT_GRADIA="$tmp_dir/bin/missing-gradia" \
  RYOKU_SCREENSHOT_SHELL="$tmp_dir/bin/missing-ryoku-shell" \
    bash bin/ryoku-cmd-screenshot "$mode" >/dev/null
}

run_gradia_helper screen
grep -qxF 'systemctl --user start xdg-desktop-portal-hyprland.service xdg-desktop-portal.service' "$tmp_dir/log" || \
  fail "Gradia screenshot mode should start the Hyprland screenshot portal"
grep -qxF 'gradia --screenshot=FULL' "$tmp_dir/log" || fail "screen mode should launch Gradia full-screen screenshot UI"

run_shell_helper region
grep -qxF 'ryoku-shell screenshot' "$tmp_dir/log" || fail "region mode should launch the Ryoku shell screenshot overlay via IPC"
! grep -q '^gradia ' "$tmp_dir/log" || fail "region mode should not bypass shell IPC with Gradia"

run_shell_helper choose
grep -qxF 'ryoku-shell screenshot' "$tmp_dir/log" || fail "choose mode should launch the Ryoku shell screenshot overlay via IPC"
! grep -q '^gradia ' "$tmp_dir/log" || fail "choose mode should not bypass shell IPC with Gradia"

run_fallback_helper screen
grep -q '^grim screen ' "$tmp_dir/log" || fail "screen mode should call grim without geometry"
grep -q '^wl-copy --type image/png$' "$tmp_dir/log" || fail "screen mode should copy the image as PNG"
grep -q '^editor ' "$tmp_dir/log" || fail "screen mode should open the screenshot in the image editor"
grep -qxF 'screen image' "$tmp_dir/clipboard" || fail "screen mode should copy the captured PNG contents"

run_fallback_helper region
grep -q '^grim region 12,34 56x78 ' "$tmp_dir/log" || fail "region mode should call grim with slurp geometry"
grep -q '^wl-copy --type image/png$' "$tmp_dir/log" || fail "region mode should copy the image as PNG"
grep -q '^editor ' "$tmp_dir/log" || fail "region mode should open the screenshot in the image editor"
grep -qxF 'region image' "$tmp_dir/clipboard" || fail "region mode should copy the captured PNG contents"

run_fallback_helper choose Screen
grep -q '^menu --dmenu --prompt Screenshot: $' "$tmp_dir/log" || fail "choose mode should open the screenshot menu"
grep -qxF 'Screen' "$tmp_dir/menu-options" || fail "choose mode should offer screen screenshots"
grep -qxF 'Drag region' "$tmp_dir/menu-options" || fail "choose mode should offer region screenshots"
grep -q '^grim screen ' "$tmp_dir/log" || fail "choose mode should take a screen screenshot when selected"
grep -qxF 'screen image' "$tmp_dir/clipboard" || fail "choose screen mode should copy the captured PNG contents"

run_fallback_helper choose "Drag region"
grep -q '^grim region 12,34 56x78 ' "$tmp_dir/log" || fail "choose mode should let users drag a region when selected"
grep -qxF 'region image' "$tmp_dir/clipboard" || fail "choose region mode should copy the captured PNG contents"

echo "PASS: Gradia is the default screenshot editor and screenshots are copied"
