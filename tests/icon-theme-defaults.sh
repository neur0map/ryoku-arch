#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_tmp=""

cleanup() {
  [[ -n ${test_tmp:-} ]] && rm -rf "$test_tmp"
}

trap cleanup EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local path="$1" pattern="$2" message="$3"

  grep -Eq "$pattern" "$ROOT_DIR/$path" || fail "$message"
}

assert_not_contains() {
  local path="$1" pattern="$2" message="$3"

  if grep -Eq "$pattern" "$ROOT_DIR/$path"; then
    fail "$message"
  fi
}

assert_executable() {
  local path="$1"

  [[ -x $ROOT_DIR/$path ]] || fail "$path should be executable"
}

assert_gtk_icon_theme() {
  local path="$1"

  assert_contains "$path" '^gtk-icon-theme-name=Papirus$' \
    "$path should default GTK icons to Papirus"
  assert_not_contains "$path" 'gtk-icon-theme-name=WhiteSur-dark' \
    "$path should not default GTK icons to missing WhiteSur-dark"
}

assert_shell_defaults() {
  grep -qxF papirus-icon-theme "$ROOT_DIR/install/ryoku-base.packages" || \
    fail "Ryoku base packages should include Papirus icons"
  assert_gtk_icon_theme "config/gtk-3.0/settings.ini"
  assert_gtk_icon_theme "config/gtk-4.0/settings.ini"
  # Qt apps (e.g. the Vicinae launcher) resolve icons through the qt6ct platform
  # theme; without a shipped qt6ct.conf they render with no app logos.
  assert_contains "config/qt6ct/qt6ct.conf" '^icon_theme=Papirus$' \
    "qt6ct config should default Qt app icons to Papirus"
  assert_not_contains "bin/ryoku-theme-set-gnome" 'icon-theme "Yaru' \
    "gnome theme setter should not hardcode the unshipped Yaru icons"
}

assert_repair_tool() {
  local home

  assert_executable "bin/ryoku-refresh-icon-theme"
  assert_contains "bin/ryoku-refresh-icon-theme" 'for candidate in Papirus Adwaita breeze hicolor' \
    "icon repair helper should prefer installed Papirus icons"
  assert_contains "migrations/1778948854.sh" 'ryoku-refresh-icon-theme' \
    "migration should repair existing user icon-theme settings"

  test_tmp=$(mktemp -d)
  home="$test_tmp/home"
  mkdir -p "$test_tmp/bin"
  mkdir -p "$home/.config/ryoku-shell" "$home/.config/gtk-3.0" "$home/.config/gtk-4.0"
  mkdir -p "$home/.local/share/icons/Papirus"
  cat >"$test_tmp/bin/gsettings" <<'GSETTINGS'
#!/bin/bash
exit 0
GSETTINGS
  chmod +x "$test_tmp/bin/gsettings"
  cat >"$home/.config/ryoku-shell/config.json" <<'JSON'
{
  "appearance": {
    "iconTheme": "WhiteSur-dark"
  }
}
JSON

  HOME="$home" \
  XDG_CONFIG_HOME="$home/.config" \
  RYOKU_PATH="$ROOT_DIR" \
  PATH="$test_tmp/bin:$ROOT_DIR/bin:$PATH" \
    "$ROOT_DIR/bin/ryoku-refresh-icon-theme" >/dev/null

  jq -e '.appearance.iconTheme == "Papirus"' "$home/.config/ryoku-shell/config.json" >/dev/null || \
    fail "icon repair helper should replace unavailable configured theme with Papirus"
  grep -qxF 'gtk-icon-theme-name=Papirus' "$home/.config/gtk-3.0/settings.ini" || \
    fail "icon repair helper should write GTK 3 Papirus setting"
  grep -qxF 'gtk-icon-theme-name=Papirus' "$home/.config/gtk-4.0/settings.ini" || \
    fail "icon repair helper should write GTK 4 Papirus setting"
  grep -qxF 'Theme=Papirus' "$home/.config/kdeglobals" || \
    fail "icon repair helper should write KDE Papirus setting"
  grep -qxF 'icon_theme=Papirus' "$home/.config/qt6ct/qt6ct.conf" || \
    fail "icon repair helper should create qt6ct Papirus setting for Qt apps"
}

assert_shell_defaults
assert_repair_tool

echo "PASS: icon theme defaults"
