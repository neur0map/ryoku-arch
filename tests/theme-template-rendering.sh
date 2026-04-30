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

assert_tofi_template_falls_back_to_accent_border() {
  local config_dir="$TEMP_DIR/fallback-config"
  local tofi_conf="$config_dir/current/next-theme/tofi.conf"

  render_to_temp_theme "$config_dir"

  [[ -f $tofi_conf ]] || fail "tofi theme config should render"
  ! grep -q '{{ ' "$tofi_conf" \
    || fail "tofi theme config should not contain unresolved template variables"
  grep -q 'border-color = #7fbbb3' "$tofi_conf" \
    || fail "tofi border color should fall back to accent when active_border_color is missing"
}

assert_tofi_template_preserves_explicit_active_border_color() {
  local config_dir="$TEMP_DIR/explicit-config"
  local next_theme="$config_dir/current/next-theme"
  local tofi_conf="$next_theme/tofi.conf"

  mkdir -p "$next_theme"
  write_base_colors "$next_theme/colors.toml"
  echo 'active_border_color = "#f2fcff"' >> "$next_theme/colors.toml"

  RYOKU_PATH="$ROOT_DIR" \
    RYOKU_CONFIG_PATH="$config_dir" \
    /bin/bash "$ROOT_DIR/bin/ryoku-theme-set-templates"

  grep -q 'border-color = #f2fcff' "$tofi_conf" \
    || fail "tofi border color should preserve explicit active_border_color"
}

assert_tofi_template_falls_back_to_accent_border
assert_tofi_template_preserves_explicit_active_border_color

echo "PASS: theme template rendering"
