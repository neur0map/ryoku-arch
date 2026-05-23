#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_no_path() {
  local path="$1"

  [[ ! -e $path && ! -L $path ]] || fail "$path should not ship after Hyprland rebirth"
}

assert_file() {
  local path="$1"

  [[ -f $path ]] || fail "$path should remain shipped after Hyprland rebirth"
}

assert_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq "$pattern" "$path" || fail "$message"
}

assert_not_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  if grep -Eq "$pattern" "$path"; then
    fail "$message"
  fi
}

assert_no_path config/niri
assert_no_path config/xdg-desktop-portal/niri-portals.conf
assert_no_path shell/scripts/__pycache__/niri-config.cpython-314.pyc
assert_no_path shell/scripts/__pycache__/parse_niri_keybinds.cpython-314.pyc
assert_no_path bin/ryoku-dev-generate-keybindings-docs

for stale_test in \
  tests/dock-niri-stale-windows.sh \
  tests/dynamic-island-ipc.sh \
  tests/inir-post-v225-upstream-fixes.sh \
  tests/niri-cleanup-migration.sh \
  tests/niri-display-configurator-ui.sh \
  tests/niri-display-output-persistence.sh \
  tests/niri-fish-startup-defaults.sh \
  tests/niri-keybinds.sh \
  tests/niri-qt-platform-fallback.sh \
  tests/niri-shell-merge-readiness.sh \
  tests/nvidia-niri-environment.sh \
  tests/shortcuts-cheatsheet-wiring.sh \
  tests/sidebar-niri-lifecycle.sh \
  tests/compositor-music-profile-duplicate.sh \
  tests/polkit-overlay.sh \
  tests/recorder-widget-redesign.sh \
  tests/settings-section-tabs.sh \
  tests/styled-combobox-object-model.sh \
  tests/translations-upstream-sync.sh; do
  assert_no_path "$stale_test"
done

for path in \
  bin/ryoku-cmd-screensaver \
  bin/ryoku-launch-screensaver \
  bin/ryoku-toggle-screensaver \
  default/alacritty/screensaver.toml \
  default/ghostty/screensaver \
  install/config/branding.sh; do
  assert_file "$path"
done

# shellcheck disable=SC2016
assert_contains bin/ryoku-cmd-screensaver 'tte -i "\$RYOKU_CONFIG_PATH/branding/screensaver\.txt"' \
  "ASCII screensaver should keep rendering the configured branding with TTE"
assert_contains config/hypr/hypridle.conf 'ryoku-launch-screensaver' \
  "Hyprland idle config should keep launching the ASCII screensaver"
assert_contains config/hypr/hyprland.conf 'org\.ryoku\.screensaver.*fullscreen true' \
  "Hyprland config should keep fullscreening the ASCII screensaver"
assert_contains install/config/branding.sh 'branding/screensaver\.txt' \
  "branding setup should keep seeding the ASCII screensaver text"

assert_not_contains install/preflight/ensure-shell-deployment.sh 'niri\.service|niri\.service\.wants' \
  "install preflight should not wire Ryoku shell to Niri"
assert_not_contains install/config/detect-keyboard-layout.sh '\.config/niri|niriconf' \
  "keyboard layout detection should not mutate Niri config"
assert_contains install/config/detect-keyboard-layout.sh 'kb_layout' \
  "keyboard layout detection should update Hyprland input settings"
assert_not_contains install/config/hardware/nvidia.sh '\.config/niri|set_niri_environment' \
  "NVIDIA setup should not create Niri environment config"
assert_contains install/config/hardware/nvidia.sh 'hyprland\.conf|set_hyprland_env' \
  "NVIDIA setup should write Hyprland environment settings"
assert_not_contains install/config/config.sh 'niri-portals|config/niri' \
  "default config installer should not copy Niri payloads"
# shellcheck disable=SC2016
assert_not_contains bin/ryoku-reinstall-configs 'cp -R "\$RYOKU_PATH/config/"\*' \
  "config reinstall should not blindly restore retired Niri payloads"

for helper in \
  bin/ryoku-cmd-screensaver \
  bin/ryoku-cmd-terminal-cwd \
  bin/ryoku-cursor-list \
  bin/ryoku-cursor-set \
  bin/ryoku-launch-or-focus \
  bin/ryoku-launch-screensaver \
  bin/ryoku-lock-qylock \
  bin/ryoku-session-recover \
  bin/ryoku-system-reboot \
  bin/ryoku-system-shutdown \
  bin/ryoku-update-git \
  bin/ryoku-windows-vm; do
  assert_not_contains "$helper" 'niri msg|NIRI_SOCKET|niri\.\*\.sock|\.config/niri' \
    "$helper should not call or configure Niri in the Hyprland path"
done

assert_not_contains config/systemd/user/ryoku-shell.service 'niri|Niri|iNiR|inir' \
  "Ryoku shell service should be compositor-neutral"
assert_no_path config/systemd/user/ryoku-shell.service.d/qt6-fractional-scale-workaround.conf
assert_not_contains .github/workflows/docs-sync.yml 'niri-keybinds|config/niri|shell/defaults/niri|parse_niri_keybinds' \
  "docs sync should not depend on retired Niri keybind tooling"

echo "PASS: rebirth source no longer ships or calls retired Niri/iNiR paths"
