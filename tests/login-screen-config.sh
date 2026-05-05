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

# -- Asset bundles -----------------------------------------------------
assert_png "shell/assets/sddm-providers/_placeholder.png"
assert_png "shell/assets/sddm-providers/ii-pixel/hero.png"
assert_png "shell/assets/sddm-providers/ii-pixel/themes/ii-pixel.png"
assert_png "shell/assets/sddm-providers/qylock/hero.png"
# Per-theme qylock PNGs are validated by the manifest sync check
# (Task 7), once the QML page declares the bundledThemes list.

# -- LoginScreenConfig.qml ---------------------------------------------
assert_file "shell/modules/settings/LoginScreenConfig.qml"
assert_grep "ContentPage"        "shell/modules/settings/LoginScreenConfig.qml"
assert_grep "property var providers" "shell/modules/settings/LoginScreenConfig.qml"
# Both providers are declared
assert_grep "providerId: \"ii-pixel\""  "shell/modules/settings/LoginScreenConfig.qml"
assert_grep "providerId: \"qylock\""    "shell/modules/settings/LoginScreenConfig.qml"
# Active-theme reader exists
assert_grep "function readActiveTheme"  "shell/modules/settings/LoginScreenConfig.qml"

# -- bundledThemes manifest sync ---------------------------------------
QML_FILE="$ROOT_DIR/shell/modules/settings/LoginScreenConfig.qml"

extract_bundled_themes() {
  # Args: provider id
  # Prints one theme name per line (or nothing if empty list).
  local provider="$1"
  awk -v provider="$provider" '
    $0 ~ "providerId: \"" provider "\"" { in_block = 1 }
    in_block && /bundledThemes:/ { in_list = 1; sub(/.*bundledThemes:[[:space:]]*\[/, ""); }
    in_list {
      while (match($0, /"[^"]+"/)) {
        s = substr($0, RSTART + 1, RLENGTH - 2)
        print s
        $0 = substr($0, RSTART + RLENGTH)
      }
      if (index($0, "]")) { in_list = 0; in_block = 0 }
    }
  ' "$QML_FILE"
}

for provider in ii-pixel qylock; do
  while IFS= read -r theme; do
    [[ -z $theme ]] && continue
    asset="shell/assets/sddm-providers/$provider/themes/$theme.png"
    assert_png "$asset"
  done < <(extract_bundled_themes "$provider")
done

# -- Page registration -------------------------------------------------
assert_grep "LoginScreenConfig\\.qml"            "shell/settings.qml"
assert_grep "LoginScreenConfig\\.qml"            "shell/modules/settings/SettingsOverlay.qml"
# Search index has at least one entry referencing the new keyword
assert_grep "qylock"                             "shell/modules/settings/SettingsOverlay.qml"

# -- Credits attribution -----------------------------------------------
assert_grep "shell/assets/sddm-providers/qylock/themes/" "CREDITS.md"

echo "PASS: tests/login-screen-config.sh ($0)"
