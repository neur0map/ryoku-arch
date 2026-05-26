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
bash -n bin/ryoku-refresh-helium-browser migrations/1779766329.sh migrations/1779768924.sh

assert_contains bin/ryoku-install-helium-browser 'ryoku-refresh-helium-browser' \
  "Helium installer should repair browser theme defaults"
assert_contains bin/ryoku-refresh-helium-browser 'net\.imput\.helium/Default/Preferences' \
  "Helium refresh helper should target Helium's Chromium profile"
assert_contains bin/ryoku-refresh-helium-browser '--ozone-platform="\$\{HELIUM_OZONE_PLATFORM:-x11\}"' \
  "Helium refresh helper should wrap Helium through XWayland by default"
assert_contains migrations/1779766329.sh 'ryoku-refresh-helium-browser' \
  "migration should refresh Helium browser profile"
assert_contains migrations/1779766329.sh '1779660083\.sh' \
  "migration should re-run webapp opacity convergence for existing installs"
assert_contains migrations/1779768924.sh 'ryoku-refresh-helium-browser' \
  "XWayland migration should refresh Helium launcher wrapper"
assert_contains migrations/1779768924.sh '1779660083\.sh' \
  "XWayland migration should re-run webapp opacity convergence"

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
data_home="$home_dir/.local/share"
helium_appimage="$data_home/ryoku-apps/helium/helium.AppImage"
helium_bin="$home_dir/.local/bin/helium"
helium_profile="$config_home/net.imput.helium"
helium_prefs="$config_home/net.imput.helium/Default/Preferences"

mkdir -p "$home_dir" "$(dirname -- "$helium_appimage")"
cat >"$helium_appimage" <<'APPIMAGE'
#!/bin/bash
printf '%s\n' "$@" >"$HOME/helium-args"
APPIMAGE
chmod 0755 "$helium_appimage"
mkdir -p "$(dirname -- "$helium_bin")"
ln -s "$helium_appimage" "$helium_bin"

HOME="$home_dir" \
XDG_CONFIG_HOME="$config_home" \
XDG_DATA_HOME="$data_home" \
RYOKU_PATH="$ROOT_DIR" \
  bin/ryoku-refresh-helium-browser >/dev/null
assert_browser_theme_default "$helium_prefs" \
  "Helium refresh helper should seed non-black theme defaults"
assert_executable "$helium_bin"
[[ ! -L $helium_bin ]] || fail "Helium wrapper should replace the legacy AppImage symlink"
grep -Fq 'helium-args' "$helium_appimage" \
  || fail "Helium wrapper should not overwrite the AppImage through the legacy symlink"
assert_contains "$helium_bin" '--ozone-platform="\$\{HELIUM_OZONE_PLATFORM:-x11\}"' \
  "Helium wrapper should default to XWayland"

HOME="$home_dir" \
XDG_DATA_HOME="$data_home" \
  "$helium_bin" about:blank
grep -Fxq -- '--ozone-platform=x11' "$home_dir/helium-args" \
  || fail "Helium wrapper should pass the XWayland ozone flag by default"
grep -Fxq -- 'about:blank' "$home_dir/helium-args" \
  || fail "Helium wrapper should preserve browser arguments"

cat >"$helium_prefs" <<'JSON'
{
  "browser": {
    "theme": {
      "color_scheme": 2,
      "color_scheme2": 2,
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

sleep 30 &
lock_pid="$!"
ln -sfn "ryoku-$lock_pid" "$helium_profile/SingletonLock"

if HOME="$home_dir" \
  XDG_CONFIG_HOME="$config_home" \
  XDG_DATA_HOME="$data_home" \
  RYOKU_PATH="$ROOT_DIR" \
  bin/ryoku-refresh-helium-browser >"$tmp_dir/running.log" 2>&1; then
  fail "Helium refresh helper should refuse to edit an open browser profile"
fi

assert_contains "$tmp_dir/running.log" 'Quit Helium completely' \
  "Helium refresh helper should explain that the browser must be closed"
jq -e '
  .browser.theme.color_scheme == 2
  and .browser.theme.user_color2 == -7558172
' "$helium_prefs" >/dev/null \
  || fail "Helium refresh helper should not rewrite an open browser profile"

rm -f "$helium_profile/SingletonLock"
kill "$lock_pid" 2>/dev/null || true
wait "$lock_pid" 2>/dev/null || true

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
XDG_DATA_HOME="$data_home" \
RYOKU_PATH="$ROOT_DIR" \
  bin/ryoku-refresh-helium-browser >/dev/null
assert_browser_theme_default "$helium_prefs" \
  "Helium refresh helper should repair black persisted theme prefs"

echo "PASS: Helium browser theme defaults"
