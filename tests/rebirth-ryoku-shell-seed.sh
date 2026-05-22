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
assert_contains shell/setup 'RYOKU_COMPOSITOR.*hyprland|HYPRLAND_INSTANCE_SIGNATURE' \
  "setup should support explicit Hyprland service handling"
assert_contains install/ryoku-base.packages '^aubio$' \
  "base packages should include native shell audio analysis dependency"
assert_contains install/ryoku-base.packages '^ttf-cascadia-code-nerd$' \
  "base packages should include the shell mono Nerd Font"
assert_contains install/ryoku-aur.packages '^app2unit$' \
  "AUR packages should include the shell app2unit runtime helper"

upstream_pattern='cae''lestia|Cae''lestia|CAELE''STIA|cae''lestia-dots|sora''mane'
if rg -n "$upstream_pattern" "$ROOT_DIR/shell" \
    --glob '!LICENSE' >/tmp/ryoku-shell-seed-names.$$; then
  cat /tmp/ryoku-shell-seed-names.$$
  rm -f /tmp/ryoku-shell-seed-names.$$
  fail "shell runtime should not expose upstream product naming outside license/credits"
fi
rm -f /tmp/ryoku-shell-seed-names.$$

echo "PASS: rebirth Ryoku shell seed is imported and product-named"
