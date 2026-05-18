#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
GREEK_NOIR_MIGRATION="$ROOT_DIR/migrations/1777005959.sh"
LIMINE_PALETTE_MIGRATION="$ROOT_DIR/migrations/1777036814.sh"
PLYMOUTH_BG_MIGRATION="$ROOT_DIR/migrations/1777039397.sh"
BRANDING_THEME_MIGRATION="$ROOT_DIR/migrations/1777765132.sh"
RYOKU_APPEARANCE_MIGRATION="$ROOT_DIR/migrations/1778043391.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_greek_noir_migration_is_retired() {
  local temp_dir home_dir bin_dir marker

  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  bin_dir="$temp_dir/bin"
  marker="$home_dir/.local/state/ryoku/independence-cutover.greek-noir.done"

  mkdir -p "$home_dir/.config/ryoku/current" "$bin_dir"
  printf 'tokyo-night\n' > "$home_dir/.config/ryoku/current/theme.name"

  cat > "$bin_dir/ryoku-theme-install" <<'EOF'
#!/bin/bash
touch "$RYOKU_TEST_INSTALL_CALLED"
EOF

  cat > "$bin_dir/ryoku-theme-set" <<'EOF'
#!/bin/bash
touch "$RYOKU_TEST_SET_CALLED"
EOF

  chmod 755 "$bin_dir/ryoku-theme-install" "$bin_dir/ryoku-theme-set"

  HOME="$home_dir" \
    PATH="$bin_dir:$PATH" \
    RYOKU_TEST_INSTALL_CALLED="$temp_dir/install-called" \
    RYOKU_TEST_SET_CALLED="$temp_dir/set-called" \
    /bin/bash "$GREEK_NOIR_MIGRATION" >/dev/null

  [[ ! -e $temp_dir/install-called ]] \
    || fail "retired Greek Noir migration should not install Greek Noir"
  [[ ! -e $temp_dir/set-called ]] \
    || fail "retired Greek Noir migration should not switch themes"
  [[ -f $marker ]] || fail "retired Greek Noir migration should mark its cutover marker"
  [[ $(cat "$home_dir/.config/ryoku/current/theme.name") == "tokyo-night" ]] \
    || fail "retired Greek Noir migration should preserve the active theme"

  rm -rf "$temp_dir"
}

assert_branding_migration_preserves_existing_theme() {
  local temp_dir home_dir bin_dir ryoku_dir

  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  bin_dir="$temp_dir/bin"
  ryoku_dir="$temp_dir/ryoku"

  mkdir -p "$home_dir/.config/ryoku/current" "$bin_dir" "$ryoku_dir/themes/ryoku"
  printf 'tokyo-night\n' > "$home_dir/.config/ryoku/current/theme.name"

  cat > "$bin_dir/ryoku-cmd-present" <<'EOF'
#!/bin/bash
exit 0
EOF

  cat > "$bin_dir/ryoku-theme-set" <<'EOF'
#!/bin/bash
echo "ryoku-theme-set should not be called when a theme is already active" >&2
exit 9
EOF

  chmod 755 "$bin_dir/ryoku-cmd-present" "$bin_dir/ryoku-theme-set"

  HOME="$home_dir" \
    PATH="$bin_dir:$PATH" \
    RYOKU_PATH="$ryoku_dir" \
    RYOKU_CONFIG_PATH="$home_dir/.config/ryoku" \
    /bin/bash "$BRANDING_THEME_MIGRATION" >/dev/null

  [[ $(cat "$home_dir/.config/ryoku/current/theme.name") == "tokyo-night" ]] \
    || fail "branding migration should preserve existing active theme"

  rm -rf "$temp_dir"
}

assert_branding_migration_does_not_set_default_theme() {
  local temp_dir home_dir bin_dir ryoku_dir

  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  bin_dir="$temp_dir/bin"
  ryoku_dir="$temp_dir/ryoku"

  mkdir -p "$home_dir/.config/ryoku/current" "$bin_dir" "$ryoku_dir/themes/ryoku"

  cat > "$bin_dir/ryoku-cmd-present" <<'EOF'
#!/bin/bash
exit 0
EOF

  cat > "$bin_dir/ryoku-theme-set" <<'EOF'
#!/bin/bash
echo "ryoku-theme-set should not be called by branding migration" >&2
exit 9
EOF

  chmod 755 "$bin_dir/ryoku-cmd-present" "$bin_dir/ryoku-theme-set"

  HOME="$home_dir" \
    PATH="$bin_dir:$PATH" \
    RYOKU_PATH="$ryoku_dir" \
    RYOKU_CONFIG_PATH="$home_dir/.config/ryoku" \
    /bin/bash "$BRANDING_THEME_MIGRATION" >/dev/null

  [[ ! -f $home_dir/.config/ryoku/current/theme.name ]] \
    || fail "branding migration should not create a Ryoku theme selection"

  rm -rf "$temp_dir"
}

assert_greek_noir_boot_color_migrations_are_retired() {
  if grep -Eq 'term_palette: 15161e|default/limine/limine.conf' "$LIMINE_PALETTE_MIGRATION"; then
    fail "Limine migration should not force Greek Noir palette colors"
  fi

  if grep -Eq 'ryoku-refresh-plymouth|Tokyo Night background constants|Greek Noir' "$PLYMOUTH_BG_MIGRATION"; then
    fail "Plymouth migration should not force Greek Noir background colors"
  fi
}

assert_shell_appearance_restore_clears_ryoku_theme_marker() {
  local temp_dir home_dir ryoku_dir user_config runtime_defaults share_defaults marker

  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  ryoku_dir="$temp_dir/ryoku"
  user_config="$home_dir/.config/ryoku-shell/config.json"
  runtime_defaults="$home_dir/.config/quickshell/ryoku-shell/defaults/config.json"
  share_defaults="$home_dir/.local/share/ryoku-shell/defaults/config.json"
  marker="$home_dir/.local/state/ryoku/independence-cutover.i""nir-appearance-defaults.done"

  mkdir -p \
    "$home_dir/.config/ryoku/current" \
    "$(dirname "$user_config")" \
    "$(dirname "$runtime_defaults")" \
    "$(dirname "$share_defaults")" \
    "$home_dir/.local/state/ryoku" \
    "$ryoku_dir/shell/defaults"

  printf 'tokyo-night\n' > "$home_dir/.config/ryoku/current/theme.name"

  cat > "$ryoku_dir/shell/defaults/config.json" <<'JSON'
{
  "appearance": {
    "theme": null,
    "palette": {
      "type": "auto",
      "accentColor": ""
    },
    "customTheme": null
  }
}
JSON

  for file in "$user_config" "$runtime_defaults" "$share_defaults"; do
    cat > "$file" <<'JSON'
{
  "appearance": {
    "theme": "custom",
    "palette": {
      "type": "scheme-tonal-spot",
      "accentColor": "#F25623"
    },
    "customTheme": {
      "m3primary": "#F25623"
    }
  },
  "hotspot": {
    "ssid": "Ryoku Hotspot"
  }
}
JSON
  done

  HOME="$home_dir" \
    RYOKU_PATH="$ryoku_dir" \
    RYOKU_STATE_PATH="$home_dir/.local/state/ryoku" \
    RYOKU_CONFIG_PATH="$home_dir/.config/ryoku" \
    PATH="$ROOT_DIR/bin:$PATH" \
    /bin/bash "$RYOKU_APPEARANCE_MIGRATION" >/dev/null

  [[ -f $marker ]] || fail "shell appearance restore migration should mark its cutover marker"
  [[ ! -f $home_dir/.config/ryoku/current/theme.name ]] \
    || fail "shell appearance restore migration should clear active Ryoku theme marker"

  for file in "$user_config" "$runtime_defaults" "$share_defaults"; do
    jq -e '.appearance.theme == null' "$file" >/dev/null \
      || fail "$file should restore the upstream default theme"
    jq -e '.appearance.palette.type == "auto" and .appearance.palette.accentColor == ""' "$file" >/dev/null \
      || fail "$file should restore auto palette defaults"
    jq -e '.appearance.customTheme == null' "$file" >/dev/null \
      || fail "$file should remove Ryoku custom color material values"
    jq -e '.hotspot.ssid == "Ryoku Hotspot"' "$file" >/dev/null \
      || fail "$file should preserve non-color Ryoku branding config"
  done

  rm -rf "$temp_dir"
}

assert_greek_noir_migration_is_retired
assert_branding_migration_preserves_existing_theme
assert_branding_migration_does_not_set_default_theme
assert_greek_noir_boot_color_migrations_are_retired
assert_shell_appearance_restore_clears_ryoku_theme_marker

echo "PASS: Ryoku theme migration preferences"
