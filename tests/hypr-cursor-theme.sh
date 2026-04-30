#!/bin/bash

set -e
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

envs="default/hypr/envs.conf"
base_packages="install/ryoku-base.packages"
aur_packages="install/ryoku-aur.packages"
migration="migrations/1777568631.sh"

for path in "$envs" "$base_packages" "$aur_packages" "$migration"; do
  [[ -f $path ]] || fail "$path missing"
done

grep -q '^env = XCURSOR_THEME,Bibata-Modern-Classic$' "$envs" \
  || fail "Hyprland should set Bibata Modern Classic as the Xcursor theme"
grep -q '^env = HYPRCURSOR_THEME,Bibata-Modern-Classic$' "$envs" \
  || fail "Hyprland should set Bibata Modern Classic as the Hyprcursor theme"
grep -q '^env = XCURSOR_SIZE,24$' "$envs" \
  || fail "Xcursor size should stay at 24"
grep -q '^env = HYPRCURSOR_SIZE,24$' "$envs" \
  || fail "Hyprcursor size should stay at 24"

grep -qx 'bibata-cursor-theme-bin' "$aur_packages" \
  || fail "Bibata cursor package should be in the default AUR package list"
grep -qx 'adwaita-cursors' "$base_packages" \
  || fail "Adwaita cursors should remain installed as fallback"

if head -n 1 "$migration" | grep -q '^#!'; then
  fail "migration should not have a shebang"
fi

grep -q '^echo "Install Bibata cursor theme and set desktop cursor preference"$' "$migration" \
  || fail "migration should start with a descriptive echo"
grep -q 'ryoku-pkg-aur-add bibata-cursor-theme-bin' "$migration" \
  || fail "migration should install Bibata for existing users when AUR is available"
grep -q 'RYOKU_ONLINE_INSTALL=1 bash "$RYOKU_PATH/install/preflight/yay-bootstrap.sh"' "$migration" \
  || fail "migration should bootstrap yay for online existing installs when needed"
grep -q 'gsettings set org.gnome.desktop.interface cursor-theme "$cursor_theme"' "$migration" \
  || fail "migration should set the GTK cursor theme when Bibata is present"

pass "hypr cursor theme"
