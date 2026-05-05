#!/bin/bash
# Static validation for the Settings -> Login screen page and its
# privileged helpers. Pure shell assertions; does not run quickshell,
# does not start SDDM, does not call any helper.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"
  [[ -f $ROOT_DIR/$path ]] || fail "missing file: $path"
}

assert_executable() {
  local path="$1"
  [[ -x $ROOT_DIR/$path ]] || fail "not executable: $path"
}

assert_grep() {
  local pattern="$1" file="$2"
  grep -qE "$pattern" "$ROOT_DIR/$file" || fail "$file: missing pattern /$pattern/"
}

assert_no_grep() {
  local pattern="$1" file="$2"
  if grep -qE "$pattern" "$ROOT_DIR/$file"; then
    fail "$file: should not contain pattern /$pattern/"
  fi
}

assert_png() {
  local path="$1"
  assert_file "$path"
  file -b "$ROOT_DIR/$path" | grep -q "PNG image data" \
    || fail "$path: not a PNG"
}

# ---------------------------------------------------------------------
# Assertions (filled in as tasks land code).
# ---------------------------------------------------------------------

# -- ryoku-set-sddm-theme ----------------------------------------------
assert_file       "bin/ryoku-set-sddm-theme"
assert_executable "bin/ryoku-set-sddm-theme"
# Must validate the theme exists under /usr/share/sddm/themes
assert_grep "/usr/share/sddm/themes/" "bin/ryoku-set-sddm-theme"
# Must write to /etc/sddm.conf.d/theme.conf
assert_grep "/etc/sddm\\.conf\\.d/theme\\.conf" "bin/ryoku-set-sddm-theme"
# Must NOT call sudo: pkexec already runs it as root
assert_no_grep "^[[:space:]]*sudo " "bin/ryoku-set-sddm-theme"
# Must refuse to run unprivileged
assert_grep "EUID" "bin/ryoku-set-sddm-theme"

# -- ryoku-install-qylock pkexec safety --------------------------------
assert_grep "EUID"        "bin/ryoku-install-qylock"
assert_grep "SUDO_USER"   "bin/ryoku-install-qylock"
# Must use the _priv wrapper instead of bare sudo for the cp/tee path
assert_grep "_priv"       "bin/ryoku-install-qylock"

# -- ryoku-uninstall-qylock --------------------------------------------
assert_file       "bin/ryoku-uninstall-qylock"
assert_executable "bin/ryoku-uninstall-qylock"
assert_grep "EUID"            "bin/ryoku-uninstall-qylock"
assert_grep "SUDO_USER"       "bin/ryoku-uninstall-qylock"
# Must reference the ii-pixel fallback by name
assert_grep "ii-pixel"        "bin/ryoku-uninstall-qylock"
# Guard list: stock SDDM themes that must never be removed by this helper
assert_grep "elarun"          "bin/ryoku-uninstall-qylock"
assert_grep "maldives"        "bin/ryoku-uninstall-qylock"
assert_grep "maya"            "bin/ryoku-uninstall-qylock"
# Must compute themes by intersection (not blindly delete from /usr/share/sddm/themes)
assert_grep "/usr/share/sddm/themes/" "bin/ryoku-uninstall-qylock"
assert_grep "\\.local/share/qylock"   "bin/ryoku-uninstall-qylock"

echo "PASS: tests/login-screen-config.sh ($0)"
