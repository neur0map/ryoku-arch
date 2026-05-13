#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"

  [[ -f $ROOT_DIR/$path ]] || fail "$path should exist"
}

assert_executable() {
  local path="$1"

  assert_file "$path"
  [[ -x $ROOT_DIR/$path ]] || fail "$path should be executable"
}

assert_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq "$pattern" "$ROOT_DIR/$path" || fail "$message"
}

assert_not_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  if grep -Eq "$pattern" "$ROOT_DIR/$path"; then
    fail "$message"
  fi
}

assert_contains_multiline() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  perl -0ne 'BEGIN { $pattern = shift } if (/$pattern/) { $found = 1; exit } END { exit($found ? 0 : 1) }' \
    "$pattern" "$ROOT_DIR/$path" || fail "$message"
}

assert_not_contains_multiline() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  if perl -0ne 'BEGIN { $pattern = shift } if (/$pattern/) { $found = 1; exit } END { exit($found ? 0 : 1) }' \
    "$pattern" "$ROOT_DIR/$path"; then
    fail "$message"
  fi
}

assert_json_expr() {
  local path="$1"
  local jq_expr="$2"
  local message="$3"

  jq -e "$jq_expr" "$ROOT_DIR/$path" >/dev/null || fail "$message"
}

assert_ryoku_theme() {
  assert_file "themes/ryoku/colors.toml"
  assert_file "themes/ryoku/btop.theme"
  assert_file "themes/ryoku/icons.theme"
  assert_file "themes/ryoku/vscode.json"
  assert_contains "themes/ryoku/colors.toml" 'accent = "#F25623"' \
    "Ryoku theme should use the approved orange accent"
  assert_contains "themes/ryoku/colors.toml" 'background = "#171717"' \
    "Ryoku theme should use the approved dark background"
}

assert_shell_overlay() {
  assert_executable "install/config/ryoku-shell-branding.sh"
  assert_file "default/ryoku-shell/config-overrides.json"
  assert_file "default/ryoku-shell/branding-replacements.tsv"
  assert_json_expr "default/ryoku-shell/config-overrides.json" 'has("appearance") | not' \
    "Ryoku shell config overlay should not override iNiR appearance colors"
  assert_json_expr "default/ryoku-shell/config-overrides.json" 'has("background") | not' \
    "Ryoku shell config overlay should not override iNiR background/theme defaults"
  assert_contains "default/ryoku-shell/config-overrides.json" '"ssid": "Ryoku Hotspot"' \
    "Ryoku shell config overlay should set the branded hotspot name"
  assert_contains "default/ryoku-shell/branding-replacements.tsv" 'Ryoku SDDM login screen' \
    "Ryoku shell replacement map should include the SDDM branding"
  assert_contains "install/config/ryoku-shell-branding.sh" 'assets/brand/logo-mark\.svg.*ryoku\.svg' \
    "Ryoku shell overlay should keep the Ryoku topbar/app logo"
  assert_not_contains "install/config/ryoku-shell-branding.sh" 'themes/ryoku/backgrounds|wallpaperPath = \$path' \
    "Ryoku shell overlay should not force Ryoku wallpaper/background colors"
  assert_not_contains "install/config/ryoku-shell-branding.sh" 'echo .*iNiR|printf .*iNiR' \
    "Ryoku shell overlay should not print upstream shell branding"
}

assert_shell_overlay_preserves_false_settings() {
  local tmp_dir="$ROOT_DIR/tmp/ryoku-shell-branding-test"
  local test_home="$tmp_dir/user"
  local config_file="$test_home/.config/ryoku-shell/config.json"

  rm -rf "$tmp_dir"
  mkdir -p "$test_home/.config/ryoku-shell"
  mkdir -p "$tmp_dir/shell/defaults"
  mkdir -p "$tmp_dir/runtime/defaults"

  cp "$ROOT_DIR/shell/defaults/config.json" "$tmp_dir/shell/defaults/config.json"
  cp "$ROOT_DIR/shell/defaults/config.json" "$tmp_dir/runtime/defaults/config.json"
  cat >"$config_file" <<'JSON'
{
  "bar": {
    "cornerStyle": 4,
    "dynamicIsland": {
      "tools": {
        "buttons": {
          "darkMode": false,
          "osk": false
        }
      }
    }
  },
  "sidebar": {
    "right": {
      "enabledWidgets": ["todo"]
    }
  }
}
JSON

  HOME="$test_home" \
    XDG_CONFIG_HOME="$test_home/.config" \
    RYOKU_PATH="$ROOT_DIR" \
    RYOKU_SHELL_PATH="$tmp_dir/shell" \
    RYOKU_SHELL_RUNTIME_PATH="$tmp_dir/runtime" \
    bash "$ROOT_DIR/install/config/ryoku-shell-branding.sh" >/dev/null

  jq -e '
    .bar.dynamicIsland.tools.buttons.darkMode == false
    and .bar.dynamicIsland.tools.buttons.osk == false
    and (.sidebar.right.enabledWidgets | index("openvpn") != null)
  ' "$config_file" >/dev/null || fail "Ryoku shell overlay should preserve explicit false user settings"

  rm -rf "$tmp_dir"
}

assert_install_wiring() {
  assert_not_contains "install/config/theme.sh" 'ryoku-theme-set' \
    "Fresh install theme setup should not force a Ryoku color theme"
  assert_not_contains "install/config/theme.sh" 'omarchy-greek-noir|HANCORE-linux|Greek Noir' \
    "Fresh install theme setup should not install the external Omarchy-derived theme"
  assert_contains "install/config/shell.sh" 'ryoku-shell-branding.sh' \
    "Shell installer should run the Ryoku branding overlay"
  assert_not_contains "install/config/shell.sh" 'missing bundled iNiR|iNiR shell' \
    "Shell installer errors should use Ryoku-facing names"
}

assert_runtime_labels() {
  assert_contains "config/systemd/user/ryoku-shell.service" 'Description=Ryoku($| shell)' \
    "User service should have a Ryoku-visible description"
  assert_not_contains "config/systemd/user/ryoku-shell.service" 'iNiR|inir shell' \
    "User service should not expose upstream shell branding"
  assert_not_contains "bin/ryoku-theme-bg-set" 'iNiR|apply_inir_background' \
    "Wallpaper setter should use Ryoku-facing shell names"
  assert_not_contains "bin/ryoku-theme-bg-next" 'iNiR|apply_inir_background' \
    "Wallpaper cycler should use Ryoku-facing shell names"
  assert_not_contains "config/matugen/config.toml" 'iNiR' \
    "Matugen template comments should use Ryoku-facing names"
}

assert_credit_kept() {
  assert_contains "CREDITS.md" 'iNiR' \
    "Upstream shell credit should remain documented"
}

assert_ryoku_theme
assert_shell_overlay
assert_shell_overlay_preserves_false_settings
assert_install_wiring
assert_runtime_labels
assert_credit_kept

echo "PASS: ryoku shell branding"
