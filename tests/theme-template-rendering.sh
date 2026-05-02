#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TEMP_DIR=$(mktemp -d)

trap 'rm -rf "$TEMP_DIR"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

write_base_colors() {
  local colors_file="$1"

  cat > "$colors_file" <<'EOF'
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
EOF
}

render_to_temp_theme() {
  local config_dir="$1"
  local next_theme="$config_dir/current/next-theme"

  mkdir -p "$next_theme"
  write_base_colors "$next_theme/colors.toml"

  RYOKU_PATH="$ROOT_DIR" \
    RYOKU_CONFIG_PATH="$config_dir" \
    /bin/bash "$ROOT_DIR/bin/ryoku-theme-set-templates"
}

assert_template_rendering() {
  local config_dir="$TEMP_DIR/config"
  local next_theme="$config_dir/current/next-theme"
  local expected_file

  render_to_temp_theme "$config_dir"

  for expected_file in \
    alacritty.toml \
    btop.theme \
    chromium.theme \
    ghostty.conf \
    keyboard.rgb \
    kitty.conf \
    obsidian.css
  do
    [[ -f $next_theme/$expected_file ]] || fail "$expected_file should render"
    ! grep -q '{{ ' "$next_theme/$expected_file" \
      || fail "$expected_file should not contain unresolved template variables"
  done

  grep -q '#7fbbb3' "$next_theme/alacritty.toml" \
    || fail "Alacritty template should include the active accent color"
  grep -q '#2d353b' "$next_theme/ghostty.conf" \
    || fail "Ghostty template should include the active background color"
  grep -q '127,187,179' "$next_theme/keyboard.rgb" \
    || fail "Keyboard RGB template should include accent RGB conversion"
}

assert_old_shell_templates_removed() {
  local removed_template

  for removed_template in \
    default/themed/hyprland.conf.tpl \
    default/themed/hyprlock.conf.tpl \
    default/themed/mako.ini.tpl \
    default/themed/noctalia-colors.json.tpl \
    default/themed/quickshell-colors.qml.tpl \
    default/themed/ryoku-shell-colors.json.tpl \
    default/themed/swayosd.css.tpl \
    default/themed/tofi.conf.tpl \
    default/themed/walker.css.tpl \
    default/themed/waybar.css.tpl
  do
    [[ ! -e $ROOT_DIR/$removed_template ]] \
      || fail "$removed_template should not remain after Niri/iNiR migration"
  done
}

assert_template_rendering
assert_old_shell_templates_removed

echo "PASS: theme template rendering"
