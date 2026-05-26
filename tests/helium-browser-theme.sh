#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq -- "$pattern" "$file" || fail "$message"
}

assert_executable() {
  local path="$1"

  [[ -x $path ]] || fail "$path should be executable"
}

assert_browser_theme_default() {
  local prefs="$1"
  local message="$2"

  jq -e '
    .browser.theme.color_scheme == 0
    and .browser.theme.color_scheme2 == 0
    and (.browser.theme.user_color == null)
    and (.browser.theme.user_color2 == null)
    and (.browser.theme.color_variant2 == null)
    and (.browser.theme.is_grayscale2 == null)
    and .extensions.theme.id == ""
    and .extensions.theme.use_system == false
    and .extensions.theme.use_custom == false
  ' "$prefs" >/dev/null || fail "$message"
}

assert_executable bin/ryoku-refresh-helium-browser
bash -n bin/ryoku-refresh-helium-browser migrations/1779766329.sh

assert_contains bin/ryoku-install-helium-browser 'ryoku-refresh-helium-browser' \
  "Helium installer should repair browser theme defaults"
assert_contains bin/ryoku-refresh-helium-browser 'net\.imput\.helium/Default/Preferences' \
  "Helium refresh helper should target Helium's Chromium profile"
assert_contains migrations/1779766329.sh 'ryoku-refresh-helium-browser' \
  "migration should refresh Helium browser profile"
assert_contains migrations/1779766329.sh '1779660083\.sh' \
  "migration should re-run webapp opacity convergence for existing installs"

jq -e '
  .browser.theme.color_scheme == 0
  and .browser.theme.color_scheme2 == 0
  and (.browser.theme.user_color == null)
' config/chromium/Default/Preferences >/dev/null \
  || fail "Chromium profile defaults should follow system appearance instead of forced dark"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
home_dir="$tmp_dir/home"
config_home="$home_dir/.config"
helium_prefs="$config_home/net.imput.helium/Default/Preferences"

mkdir -p "$home_dir"
HOME="$home_dir" \
XDG_CONFIG_HOME="$config_home" \
RYOKU_PATH="$ROOT_DIR" \
  bin/ryoku-refresh-helium-browser >/dev/null
assert_browser_theme_default "$helium_prefs" \
  "Helium refresh helper should seed non-black theme defaults"

cat >"$helium_prefs" <<'JSON'
{
  "browser": {
    "theme": {
      "color_scheme": 2,
      "color_scheme2": 2,
      "color_variant2": 1,
      "is_grayscale2": true,
      "user_color": 2,
      "user_color2": -7558172
    }
  },
  "extensions": {
    "theme": {
      "id": "custom",
      "use_system": true,
      "use_custom": true
    }
  }
}
JSON

HOME="$home_dir" \
XDG_CONFIG_HOME="$config_home" \
RYOKU_PATH="$ROOT_DIR" \
  bin/ryoku-refresh-helium-browser >/dev/null
assert_browser_theme_default "$helium_prefs" \
  "Helium refresh helper should repair black persisted theme prefs"

echo "PASS: Helium browser theme defaults"
