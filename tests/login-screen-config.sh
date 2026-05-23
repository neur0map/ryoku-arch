#!/bin/bash

set -euo pipefail

# Login screen / SDDM contract guard for the rebirth state.
#
# Post-rebirth:
#   * The login manager is SDDM driven by the qylock clockwork/orbital
#     theme (Darkkal44/qylock). The legacy ii-pixel theme bundle and the
#     bin/ryoku-refresh-sddm helper that installed it have been retired.
#   * install/login/sddm.sh installs qylock + enables sddm.service +
#     flips default.target to graphical.target. It must not call any
#     missing helpers and must not require ii-pixel.
#   * bin/ryoku-install-qylock + bin/ryoku-uninstall-qylock manage the
#     qylock state.

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  [[ -f "$ROOT_DIR/$1" ]] || fail "missing file: $1"
}

assert_executable() {
  [[ -x "$ROOT_DIR/$1" ]] || fail "not executable: $1"
}

assert_grep() {
  local pattern="$1"
  local path="$ROOT_DIR/$2"
  grep -qE "$pattern" "$path" || fail "$path missing pattern: $pattern"
}

assert_no_grep() {
  local pattern="$1"
  local path="$ROOT_DIR/$2"
  if grep -qE "$pattern" "$path" 2>/dev/null; then
    fail "$path must not contain pattern: $pattern"
  fi
}

# install/login/sddm.sh contract for the rebirth path.
sddm_sh="install/login/sddm.sh"
assert_file "$sddm_sh"

assert_grep 'ryoku-install-qylock' "$sddm_sh"
assert_grep 'sudo systemctl enable sddm.service' "$sddm_sh"
assert_grep 'sudo systemctl set-default graphical.target' "$sddm_sh"

# orbital theme must be the required-present check; ii-pixel is gone.
assert_grep '/usr/share/sddm/themes/orbital/metadata.desktop' "$sddm_sh"
assert_no_grep '/usr/share/sddm/themes/ii-pixel' "$sddm_sh"

# bin/ryoku-refresh-sddm called install-pixel-sddm.sh which no longer
# exists in the rebirth shell tree, so the wrapper must be gone too.
assert_no_grep 'ryoku-refresh-sddm' "$sddm_sh"
[[ ! -e "$ROOT_DIR/bin/ryoku-refresh-sddm" ]] \
  || fail "bin/ryoku-refresh-sddm should be removed post-rebirth (called missing install-pixel-sddm.sh)"

# Hyprland session must still be required so SDDM does not land us on a
# different compositor that the rebirth shell does not target.
assert_grep 'hyprland.desktop|Hyprland.desktop|hyprland-uwsm.desktop' "$sddm_sh"

# qylock installer presence + executable bit.
assert_file       "bin/ryoku-install-qylock"
assert_executable "bin/ryoku-install-qylock"
assert_file       "bin/ryoku-uninstall-qylock"
assert_executable "bin/ryoku-uninstall-qylock"

# Native plugin build toolchain MUST stay in ryoku-base.packages so the
# Ryoku QML plugin (Ryoku.Config + Ryoku.Services) can be rebuilt during
# install. Without these the shell fails to load with
# "Type Background unavailable" + "module Ryoku.Config is not installed".
grep -qE '^cmake$' "$ROOT_DIR/install/ryoku-base.packages" \
  || fail "install/ryoku-base.packages must include cmake (shell/setup needs it to build the native plugin)"
grep -qE '^ninja$' "$ROOT_DIR/install/ryoku-base.packages" \
  || fail "install/ryoku-base.packages must include ninja (shell/setup needs it for the qt6 build)"

# cava-ryoku must be wired into the install pipeline so the plugin's
# REQUIRED libcava dep is satisfied; otherwise the cmake configure step
# bails with "Package 'libcava' not found".
assert_file       "install/packaging/distro-arch.sh"
assert_executable "install/packaging/distro-arch.sh"
assert_grep 'cava-ryoku' "install/packaging/distro-arch.sh"
assert_grep 'distro-arch\.sh' "install/packaging/all.sh"

echo "PASS: rebirth SDDM/qylock contract intact (ii-pixel + ryoku-refresh-sddm retired)"
