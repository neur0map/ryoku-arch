#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"

  [[ -f $ROOT_DIR/$path ]] || fail "missing $path"
}

assert_executable() {
  local path="$1"

  [[ -x $ROOT_DIR/$path ]] || fail "missing executable $path"
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

assert_file shell/shell.qml
assert_file shell/CMakeLists.txt
assert_file shell/LICENSE
assert_file shell/plugin/src/Ryoku/CMakeLists.txt
assert_file shell/modules/Shortcuts.qml
assert_executable shell/scripts/ryoku-shell
assert_executable shell/scripts/ryoku
assert_executable shell/setup

assert_contains shell/CMakeLists.txt 'project\(ryoku-shell' \
  "shell CMake project should use Ryoku naming"
assert_contains shell/CMakeLists.txt 'INSTALL_QSCONFDIR "etc/xdg/quickshell/ryoku-shell"' \
  "shell CMake install path should use ryoku-shell"
assert_contains shell/utils/Paths.qml '/ryoku-shell`' \
  "shell user paths should use ryoku-shell"
assert_contains shell/components/misc/CustomShortcut.qml 'appid: "ryoku"' \
  "global shortcuts should use Ryoku app id"
assert_contains shell/scripts/ryoku-shell 'RYOKU_COMPOSITOR.*hyprland|HYPRLAND_INSTANCE_SIGNATURE' \
  "launcher should support explicit Hyprland service handling"
assert_contains shell/scripts/ryoku-shell 'ipc_call controlCenter toggle' \
  "settings command should toggle the control center instead of spawning duplicates"
assert_contains shell/setup 'RYOKU_COMPOSITOR.*hyprland|HYPRLAND_INSTANCE_SIGNATURE' \
  "setup should support explicit Hyprland service handling"
assert_contains shell/setup "scripts/ryoku\" \"\\\$bin_dir/ryoku" \
  "setup should install the imported shell compatibility bridge"
assert_contains shell/modules/controlcenter/WindowFactory.qml 'function close' \
  "control center window factory should expose a close path"
assert_contains shell/modules/controlcenter/WindowFactory.qml 'function toggle' \
  "control center window factory should expose a toggle path"
assert_contains shell/modules/Shortcuts.qml 'WindowFactory.toggle' \
  "control center shortcuts should toggle the existing window"
assert_contains shell/assets/systemd/ryoku-shell.service 'Environment=PATH=.*\.local/bin' \
  "service should expose user-installed Ryoku bridge commands"
assert_contains shell/scripts/ryoku 'ryoku-wallpaper-apply' \
  "compatibility bridge should delegate wallpaper application to Ryoku commands"
assert_contains shell/scripts/ryoku 'ryoku-doctor' \
  "compatibility bridge should expose the global doctor command"
assert_contains install/ryoku-base.packages '^aubio$' \
  "base packages should include native shell audio analysis dependency"
assert_contains install/ryoku-base.packages '^ttf-cascadia-code-nerd$' \
  "base packages should include the shell mono Nerd Font"
assert_contains install/ryoku-aur.packages '^app2unit$' \
  "AUR packages should include the shell app2unit runtime helper"

command -v jq >/dev/null 2>&1 || fail "jq is required for the shell bridge test"
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

HOME="$tmp_dir/home" XDG_STATE_HOME="$tmp_dir/state" \
  "$ROOT_DIR/shell/scripts/ryoku" scheme list | jq -e '.ryoku.default.primary == "F25623"' >/dev/null || \
  fail "compatibility bridge should expose a shell-readable scheme list"

current_scheme=$(
  HOME="$tmp_dir/home" XDG_STATE_HOME="$tmp_dir/state" \
    "$ROOT_DIR/shell/scripts/ryoku" scheme get -nfv
)
[[ $current_scheme == $'ryoku\ndefault\ntonalspot' ]] || \
  fail "compatibility bridge should expose current scheme fields"

HOME="$tmp_dir/home" XDG_STATE_HOME="$tmp_dir/state" \
  "$ROOT_DIR/shell/scripts/ryoku" scheme set -v expressive
HOME="$tmp_dir/home" XDG_STATE_HOME="$tmp_dir/state" \
  "$ROOT_DIR/shell/scripts/ryoku" scheme get | jq -e '.variant == "expressive"' >/dev/null || \
  fail "compatibility bridge should persist shell variant changes"

HOME="$tmp_dir/home" XDG_STATE_HOME="$tmp_dir/state" \
  "$ROOT_DIR/shell/scripts/ryoku" wallpaper -p "$tmp_dir/wall.png" | jq -e '.variant == "expressive" and .colours.primary == "F56E0F" and .colours.surface == "171717"' >/dev/null || \
  fail "compatibility bridge should expose preview wallpaper colours from the current mode and variant"

mkdir -p "$tmp_dir/installed/bin"
cat >"$tmp_dir/installed/bin/ryoku-doctor" <<'SH'
#!/bin/bash
printf '%s' "$*" >"$RYOKU_DOCTOR_ARGS"
echo "global doctor selected"
SH
chmod 755 "$tmp_dir/installed/bin/ryoku-doctor"

doctor_args="$tmp_dir/doctor-args"
doctor_output=$(
  HOME="$tmp_dir/home" \
  XDG_STATE_HOME="$tmp_dir/state" \
  RYOKU_PATH="$tmp_dir/installed" \
  RYOKU_DOCTOR_ARGS="$doctor_args" \
    "$ROOT_DIR/shell/scripts/ryoku" doctor 2>&1
) || fail "compatibility bridge should run global ryoku doctor: $doctor_output"
[[ $doctor_output == "global doctor selected" ]] || \
  fail "compatibility bridge should run the installed global doctor"
[[ ! -s $doctor_args ]] || \
  fail "ryoku doctor should run the smart global doctor without forcing shell mode"

HOME="$tmp_dir/install-home" \
XDG_BIN_HOME="$tmp_dir/bin" \
XDG_CONFIG_HOME="$tmp_dir/config" \
XDG_DATA_HOME="$tmp_dir/data" \
XDG_STATE_HOME="$tmp_dir/state-install" \
RYOKU_SHELL_RUNTIME_DIR="$tmp_dir/runtime" \
RYOKU_SHELL_LIB_DIR="$tmp_dir/lib" \
RYOKU_SHELL_QML_DIR="$tmp_dir/qml" \
  "$ROOT_DIR/shell/setup" install --skip-build >/dev/null

[[ -s $tmp_dir/install-home/.face ]] || \
  fail "setup should install a default face image for first-run shell startup"
[[ -f $tmp_dir/state-install/ryoku-shell/scheme.json ]] || \
  fail "setup should initialize shell scheme state"
[[ -f $tmp_dir/state-install/ryoku-shell/wallpaper/path.txt ]] || \
  fail "setup should initialize shell wallpaper state"
[[ $(<"$tmp_dir/runtime/.ryoku-source-path") == "$ROOT_DIR" ]] || \
  fail "setup should stamp the source repo path into the runtime"

HOME="$tmp_dir/runtime-home" \
XDG_BIN_HOME="$tmp_dir/runtime-bin" \
XDG_CONFIG_HOME="$tmp_dir/runtime-config" \
XDG_DATA_HOME="$tmp_dir/runtime-data" \
XDG_STATE_HOME="$tmp_dir/runtime-state" \
RYOKU_SHELL_RUNTIME_DIR="$tmp_dir/runtime-from-runtime" \
RYOKU_SHELL_LIB_DIR="$tmp_dir/runtime-lib" \
RYOKU_SHELL_QML_DIR="$tmp_dir/runtime-qml" \
  "$tmp_dir/runtime/setup" install --skip-build >/dev/null

[[ $(<"$tmp_dir/runtime-from-runtime/.ryoku-source-path") == "$ROOT_DIR" ]] || \
  fail "runtime setup should preserve the original source repo path"

upstream_pattern='cae''lestia|Cae''lestia|CAELE''STIA|cae''lestia-dots|sora''mane'
# Exclude LICENSE (legal text) and the About settings pane's credits
# section (intentional attribution to the upstream shell heritage, same
# rationale as the repo-root CREDITS.md exemption in rebirth-docs-ready).
if rg -n "$upstream_pattern" "$ROOT_DIR/shell" \
    --glob '!LICENSE' \
    --glob '!AboutPane.qml' \
    --glob '!RyokuAbout.qml' >/tmp/ryoku-shell-seed-names.$$; then
  cat /tmp/ryoku-shell-seed-names.$$
  rm -f /tmp/ryoku-shell-seed-names.$$
  fail "shell runtime should not expose upstream product naming outside license/credits"
fi
rm -f /tmp/ryoku-shell-seed-names.$$

echo "PASS: rebirth Ryoku shell seed is imported and product-named"
