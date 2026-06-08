#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"

  [[ -f $path ]] || fail "$path should exist"
}

assert_executable() {
  local path="$1"

  assert_file "$path"
  [[ -x $path ]] || fail "$path should be executable"
}

assert_no_path() {
  local path="$1"

  [[ ! -e $path ]] || fail "$path should not exist"
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq -- "$pattern" "$file" || fail "$message"
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if grep -Eq -- "$pattern" "$file"; then
    fail "$message"
  fi
}

assert_no_path bin/ryoku-lock-qylock
assert_no_path tests/qylock-lock-helper-behavior.sh

assert_contains config/hypr/hypridle.conf 'lock_cmd[[:space:]]*=[[:space:]]*/bin/sh -c .*env -u QS_CONFIG_NAME -u QS_CONFIG_PATH -u QS_MANIFEST .*quickshell-lockscreen/lock\.sh' \
  "lid/idle lock should call qylock's upstream lock script directly"
assert_not_contains config/hypr/hypridle.conf 'ryoku-lock-qylock' \
  "lid/idle lock should not call the Ryoku qylock compatibility bridge"
assert_not_contains config/hypr/hypridle.conf 'lock_cmd[[:space:]]*=[[:space:]]*pidof hyprlock \|\| hyprlock' \
  "lid/idle lock should not go straight to hyprlock"

assert_contains config/hypr/hyprland.lua '^local var_lockscreen[[:space:]]*=.*env -u QS_CONFIG_NAME -u QS_CONFIG_PATH -u QS_MANIFEST .*quickshell-lockscreen/lock\.sh' \
  "manual lock command should point at qylock's upstream lock script"
assert_contains config/hypr/hyprland.lua 'hl\.bind\("SUPER \+ ALT \+ L", hl\.dsp\.exec_cmd\(var_lockscreen\)\)' \
  "manual Super+Alt+L lock should call qylock directly"
assert_not_contains config/hypr/hyprland.lua 'hl\.bind\("SUPER \+ ALT \+ L", hl\.dsp\.exec_cmd\("[^"]*loginctl lock-session' \
  "manual Super+Alt+L lock should not depend on hypridle to launch qylock"

assert_no_path shell/modules/lock
assert_not_contains shell/shell.qml 'modules/lock|Lock[[:space:]]*\{' \
  "Ryoku shell should not load the retired internal lock surface"
assert_file shell/modules/LockBridge.qml
assert_contains shell/shell.qml 'LockBridge[[:space:]]*\{' \
  "Ryoku shell should load the qylock IPC bridge"
assert_contains shell/modules/LockBridge.qml 'target:[[:space:]]*"lock"' \
  "Ryoku shell should expose a lock IPC target"
assert_contains shell/modules/LockBridge.qml 'function lock\(\): string' \
  "Ryoku lock IPC should expose a lock action"
assert_contains shell/modules/LockBridge.qml 'function unlock\(\): string' \
  "Ryoku lock IPC should expose an unlock action"
assert_contains shell/modules/LockBridge.qml 'function isLocked\(\): string' \
  "Ryoku lock IPC should expose a status action"
assert_contains shell/modules/LockBridge.qml 'quickshell-lockscreen/lock\.sh' \
  "Ryoku lock IPC should delegate to qylock's upstream lock script"
assert_not_contains shell/modules/LockBridge.qml 'WlSessionLock|modules/lock|import "lock"' \
  "Ryoku lock IPC bridge should not restore the retired internal lock surface"
assert_not_contains shell/modules/IdleMonitors.qml 'required property Lock|root\.lock|WlSessionLock|modules/lock|import "lock"' \
  "Ryoku idle monitors should not control the retired internal lock surface"
assert_contains shell/modules/IdleMonitors.qml 'loginctl.*lock-session' \
  "Ryoku idle lock actions should hand off to logind/hypridle instead of internal lock UI"
assert_contains shell/scripts/ryoku-shell 'ipc call lock lock' \
  "ryoku-shell lock should use the Ryoku lock IPC target first"
assert_contains shell/scripts/ryoku-shell 'quickshell-lockscreen/lock\.sh' \
  "ryoku-shell lock should fall back to qylock if IPC is unavailable"

assert_contains bin/ryoku-install-qylock 'quickshell-lockscreen' \
  "qylock install should deploy the Quickshell lockscreen files"
assert_contains bin/ryoku-install-qylock '\.config/qylock/theme' \
  "qylock install should write qylock's own default lockscreen theme config"
assert_contains bin/ryoku-install-qylock 'DEFAULT_THEME="clockwork/orbital"' \
  "qylock default install should use the clockwork orbital variant"
assert_contains bin/ryoku-install-qylock 'normalize_qylock_theme' \
  "qylock install should normalize clockwork to its upstream default variant"
assert_contains migrations/1779504291.sh 'DEFAULT_QYLOCK_THEME="clockwork/orbital"' \
  "qylock migration should seed clockwork as the default lockscreen theme"
assert_contains bin/ryoku-install-qylock 'themes_link' \
  "qylock install should link the lockscreen theme directory"
assert_contains bin/ryoku-uninstall-qylock 'quickshell-lockscreen' \
  "qylock uninstall should remove the Quickshell lockscreen files"
assert_contains bin/ryoku-uninstall-qylock 'nested_dir' \
  "qylock uninstall should remove nested upstream variants like clockwork/orbital"

assert_executable default/systemd/system-sleep/ryoku-qylock-prelock
bash -n default/systemd/system-sleep/ryoku-qylock-prelock || fail "ryoku-qylock-prelock has a syntax error"

assert_contains default/systemd/system-sleep/ryoku-qylock-prelock '/etc/sddm\.conf' \
  "qylock pre-sleep hook should use the Settings-selected SDDM theme"
assert_contains default/systemd/system-sleep/ryoku-qylock-prelock '\.local/share/qylock/themes' \
  "qylock pre-sleep hook should only delay sleep when the active theme belongs to qylock"
assert_contains default/systemd/system-sleep/ryoku-qylock-prelock 'qylock_theme_source_path' \
  "qylock pre-sleep hook should not delay suspend for invalid qylock parent directories"
assert_contains default/systemd/system-sleep/ryoku-qylock-prelock "\\\$theme_path/Main\\.qml" \
  "qylock pre-sleep hook should validate the resolved theme directory"
assert_contains default/systemd/system-sleep/ryoku-qylock-prelock 'clockwork/orbital' \
  "qylock pre-sleep hook should recognize the default clockwork variant"
assert_contains default/systemd/system-sleep/ryoku-qylock-prelock 'loginctl list-sessions' \
  "qylock pre-sleep hook should inspect active sessions before delaying suspend"
assert_not_contains default/systemd/system-sleep/ryoku-qylock-prelock 'loginctl lock-session' \
  "qylock pre-sleep hook should not emit a duplicate LockSession while hypridle is already locking"
assert_contains default/systemd/system-sleep/ryoku-qylock-prelock 'RYOKU_QYLOCK_PRELOCK_DELAY' \
  "qylock pre-sleep hook should give qylock a configurable render window before suspend"
assert_not_contains default/systemd/system-sleep/ryoku-qylock-prelock '/home/[a-z][a-z0-9_-]*' \
  "qylock pre-sleep hook should not hard-code any user home path"

assert_contains install/config/session-recover.sh 'ryoku-qylock-prelock' \
  "session sleep hooks installer should install the qylock pre-sleep guard"

assert_not_contains bin/ryoku-shell-cleanup-orphans 'quickshell-lockscreen' \
  "shell cleanup should not target the qylock session-lock client"

echo "PASS: tests/qylock-lockscreen.sh"
