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

assert_executable bin/ryoku-lock-qylock
bash -n bin/ryoku-lock-qylock || fail "ryoku-lock-qylock has a syntax error"
assert_executable tests/qylock-lock-helper-behavior.sh

assert_contains bin/ryoku-lock-qylock '\.local/share/quickshell-lockscreen/lock\.sh' \
  "qylock lock helper should execute qylock's Quickshell lockscreen"
assert_contains bin/ryoku-lock-qylock 'hyprlock' \
  "qylock lock helper should keep hyprlock as fallback"
assert_contains bin/ryoku-lock-qylock 'pgrep .*quickshell.*quickshell-lockscreen/lock_shell\.qml' \
  "qylock lock helper should avoid duplicate qylock lock instances"
assert_contains bin/ryoku-lock-qylock '/etc/sddm\.conf' \
  "qylock lock helper should use the Settings-selected SDDM theme as the lockscreen selector"
assert_contains bin/ryoku-lock-qylock 'QYLOCK_DIR.*/themes/.theme' \
  "qylock lock helper should use qylock only when the active theme belongs to qylock"
assert_contains bin/ryoku-lock-qylock 'QYLOCK_DIR.*/themes/.theme/Main\.qml' \
  "qylock lock helper should only use qylock themes that have a Main.qml entrypoint"
assert_contains bin/ryoku-lock-qylock 'QYLOCK_LOCK_SCRIPT.*.theme' \
  "qylock lock helper should pass the selected theme to qylock instead of relying on a side config"
assert_contains bin/ryoku-lock-qylock 'exec "\$QYLOCK_LOCK_SCRIPT" "\$theme"' \
  "qylock lock helper should hand off to qylock instead of launching hyprlock after qylock exits"
assert_not_contains bin/ryoku-lock-qylock 'if ! "\$QYLOCK_LOCK_SCRIPT" "\$theme"' \
  "qylock lock helper should not treat qylock unlock/termination as a startup failure"
assert_contains bin/ryoku-lock-qylock 'hydrate_graphical_env' \
  "qylock lock helper should hydrate Wayland/Niri environment before launching Quickshell"
assert_contains bin/ryoku-lock-qylock 'systemctl --user show-environment' \
  "qylock lock helper should import graphical session variables from the user manager"
assert_contains bin/ryoku-lock-qylock 'WAYLAND_DISPLAY' \
  "qylock lock helper should guarantee WAYLAND_DISPLAY for non-terminal launches"
assert_contains bin/ryoku-lock-qylock 'NIRI_SOCKET' \
  "qylock lock helper should guarantee NIRI_SOCKET for Niri lock sessions"
assert_contains bin/ryoku-lock-qylock 'patch_qylock_unlock_sequence' \
  "qylock lock helper should patch qylock's delayed unlock sequence"
assert_contains bin/ryoku-lock-qylock 'shellRoot\.sessionLocked = false' \
  "qylock lock helper should release the Wayland session lock before logind unlock"

assert_contains config/hypr/hypridle.conf 'lock_cmd[[:space:]]*=[[:space:]]*.*ryoku-lock-qylock' \
  "lid/idle lock should prefer qylock lockscreen"
assert_contains config/hypr/hypridle.conf '\$HOME/\.local/share/ryoku/bin/ryoku-lock-qylock' \
  "lid/idle lock should call the Ryoku helper by absolute HOME-based path because hypridle may start before PATH is imported"
assert_not_contains config/hypr/hypridle.conf 'lock_cmd[[:space:]]*=[[:space:]]*ryoku-lock-qylock' \
  "lid/idle lock should not rely on PATH to find the Ryoku helper"
assert_not_contains config/hypr/hypridle.conf 'lock_cmd[[:space:]]*=[[:space:]]*pidof hyprlock \|\| hyprlock' \
  "lid/idle lock should not go straight to hyprlock"

assert_contains config/niri/config.d/70-binds.kdl 'Mod\+Alt\+L.*ryoku-shell.*lock.*activate' \
  "manual Mod+Alt+L lock should remain Ryoku Quickshell"

assert_contains bin/ryoku-install-qylock 'quickshell-lockscreen' \
  "qylock install should deploy the Quickshell lockscreen files"
assert_not_contains bin/ryoku-install-qylock '\.config/qylock' \
  "qylock install should not write a separate lockscreen override config"
assert_contains bin/ryoku-install-qylock 'themes_link' \
  "qylock install should link the lockscreen theme directory"
assert_contains bin/ryoku-uninstall-qylock 'quickshell-lockscreen' \
  "qylock uninstall should remove the Quickshell lockscreen files"

assert_executable default/systemd/system-sleep/ryoku-qylock-prelock
bash -n default/systemd/system-sleep/ryoku-qylock-prelock || fail "ryoku-qylock-prelock has a syntax error"

assert_contains default/systemd/system-sleep/ryoku-qylock-prelock '/etc/sddm\.conf' \
  "qylock pre-sleep hook should use the Settings-selected SDDM theme"
assert_contains default/systemd/system-sleep/ryoku-qylock-prelock '\.local/share/qylock/themes' \
  "qylock pre-sleep hook should only delay sleep when the active theme belongs to qylock"
assert_contains default/systemd/system-sleep/ryoku-qylock-prelock '\.local/share/qylock/themes/.theme/Main\.qml' \
  "qylock pre-sleep hook should not delay suspend for invalid qylock parent directories"
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

# ryoku-shell cleanup-orphans must NOT kill the qylock session-lock client.
# Its parent is hypridle's lock.sh wrapper (not ryoku-shell.service), so the
# generic ppid==MainPID guard in cleanup_orphans() does not protect it.
# Killing it during a resume cycle while niri's session-lock is still active
# leaves niri rendering its lock-surface-lost magenta backdrop with no input.
assert_contains shell/scripts/ryoku-shell 'quickshell-lockscreen' \
  "cleanup_orphans must skip the qylock session-lock client by cmdline match"

tests/qylock-lock-helper-behavior.sh >/dev/null \
  || fail "qylock lock helper behavior regression"

echo "PASS: tests/qylock-lockscreen.sh"
