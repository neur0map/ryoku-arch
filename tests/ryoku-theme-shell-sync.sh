#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_DIR="$(mktemp -d)"

trap 'rm -rf "$TEMP_DIR"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_json_eq() {
  local file="$1"
  local query="$2"
  local expected="$3"
  local actual

  actual="$(jq -r "$query" "$file")"
  [[ $actual == "$expected" ]] || fail "$query should be $expected, got $actual"
}

config_dir="$TEMP_DIR/ryoku-config"
home_dir="$TEMP_DIR/home"
shell_config="$home_dir/.config/inir/config.json"

mkdir -p \
  "$config_dir/current/theme" \
  "$home_dir/.config/inir"

cat >"$config_dir/current/theme/colors.toml" <<'COLORS'
accent = "#7fbbb3"
cursor = "#d3c6aa"
foreground = "#d3c6aa"
background = "#2d353b"
selection_foreground = "#2d353b"
selection_background = "#d3c6aa"

color0 = "#475258"
color1 = "#e67e80"
color2 = "#a7c080"
color3 = "#dbbc7f"
color4 = "#7fbbb3"
color5 = "#d699b6"
color6 = "#83c092"
color7 = "#d3c6aa"
color8 = "#475258"
color9 = "#e67e80"
color10 = "#a7c080"
color11 = "#dbbc7f"
color12 = "#7fbbb3"
color13 = "#d699b6"
color14 = "#83c092"
color15 = "#d3c6aa"
COLORS

printf 'background = "#2d353b"\n' >"$config_dir/current/theme/alacritty.toml"
printf 'background #2d353b\n' >"$config_dir/current/theme/kitty.conf"
printf 'theme[main_bg]="#2d353b"\n' >"$config_dir/current/theme/btop.theme"

cat >"$shell_config" <<'JSON'
{
  "appearance": {
    "theme": "auto",
    "palette": {
      "type": "auto",
      "accentColor": ""
    },
    "wallpaperTheming": {
      "enableAppsAndShell": true,
      "enableTerminal": true,
      "enableQtApps": true,
      "enableVSCode": true,
      "enableChrome": true,
      "enableVesktop": true,
      "enableZed": true,
      "enablePearDesktop": true
    }
  }
}
JSON

HOME="$home_dir" \
  XDG_CONFIG_HOME="$home_dir/.config" \
  RYOKU_PATH="$ROOT_DIR" \
  RYOKU_CONFIG_PATH="$config_dir" \
  "$ROOT_DIR/bin/ryoku-theme-set-shell"

assert_json_eq "$shell_config" '.appearance.theme' "custom"
assert_json_eq "$shell_config" '.appearance.palette.accentColor' "#7fbbb3"
assert_json_eq "$shell_config" '.appearance.wallpaperTheming.enableAppsAndShell' "false"
assert_json_eq "$shell_config" '.appearance.wallpaperTheming.enableTerminal' "false"

grep -q '#2d353b' "$home_dir/.config/alacritty/colors.toml" \
  || fail "Alacritty shell color file should use the selected Ryoku theme"
grep -q '#2d353b' "$home_dir/.config/kitty/current-theme.conf" \
  || fail "Kitty shell color file should use the selected Ryoku theme"
grep -q '#2d353b' "$home_dir/.config/btop/themes/ii-auto.theme" \
  || fail "btop shell color file should use the selected Ryoku theme"

echo "PASS: ryoku theme shell sync"
