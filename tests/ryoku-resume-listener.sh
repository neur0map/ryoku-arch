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

  grep -Eq -- "$pattern" "$ROOT_DIR/$path" || fail "$message"
}

assert_listener_installer() {
  assert_executable "install/config/ryoku-resume-listener.sh"
  assert_contains "install/config/ryoku-resume-listener.sh" 'config/systemd/user/ryoku-resume-listener\.service' \
    "Installer should reference the unit source file in the repo"
  assert_contains "install/config/ryoku-resume-listener.sh" 'UNIT_DEST=.*ryoku-resume-listener\.service' \
    "Installer should assign the destination path including the unit filename"
  assert_contains "install/config/ryoku-resume-listener.sh" '\$\{XDG_CONFIG_HOME:-\$HOME/\.config\}/systemd/user' \
    "Installer should target the user systemd directory under XDG_CONFIG_HOME"
  assert_contains "install/config/ryoku-resume-listener.sh" 'systemctl --user daemon-reload' \
    "Installer should reload the user systemd manager"
  assert_contains "install/config/ryoku-resume-listener.sh" 'systemctl --user enable --now ryoku-resume-listener\.service' \
    "Installer should enable and immediately start the listener service"
}

assert_listener_unit() {
  assert_file "config/systemd/user/ryoku-resume-listener.service"
  assert_contains "config/systemd/user/ryoku-resume-listener.service" 'Description=' \
    "Unit should have a Description"
  assert_contains "config/systemd/user/ryoku-resume-listener.service" 'Type=simple' \
    "Unit should be Type=simple (gdbus monitor is long-running)"
  assert_contains "config/systemd/user/ryoku-resume-listener.service" 'Restart=on-failure' \
    "Unit should restart on failure so a bus disconnect recovers"
  assert_contains "config/systemd/user/ryoku-resume-listener.service" 'RestartSec=5' \
    "Unit should back off 5 seconds before restarting"
  assert_contains "config/systemd/user/ryoku-resume-listener.service" 'After=graphical-session\.target' \
    "Unit should be ordered after the graphical session"
  assert_contains "config/systemd/user/ryoku-resume-listener.service" 'PartOf=graphical-session\.target' \
    "Unit should be PartOf the graphical session so it stops with it"
  assert_contains "config/systemd/user/ryoku-resume-listener.service" 'WantedBy=graphical-session\.target' \
    "Unit should be WantedBy the graphical session for enable-time wiring"
  assert_contains "config/systemd/user/ryoku-resume-listener.service" 'ExecStart=.*ryoku-resume-listener$' \
    "Unit ExecStart should point at the ryoku-resume-listener binary"
}

assert_listener_script() {
  assert_executable "bin/ryoku-resume-listener"
  assert_contains "bin/ryoku-resume-listener" 'gdbus monitor' \
    "Listener should use gdbus monitor to read the system bus"
  assert_contains "bin/ryoku-resume-listener" '--system' \
    "Listener should subscribe on the system bus"
  assert_contains "bin/ryoku-resume-listener" '--dest org\.freedesktop\.login1' \
    "Listener should target the systemd-logind destination"
  assert_contains "bin/ryoku-resume-listener" 'PrepareForSleep' \
    "Listener should match the PrepareForSleep signal name"
  assert_contains "bin/ryoku-resume-listener" '\\\(false,\\\)' \
    "Listener should match the falsey (resume) argument shape"
  assert_contains "bin/ryoku-resume-listener" 'RECOVER_BIN.*--quiet.*--resume' \
    "Listener should invoke the recovery binary with --quiet and --resume on the resume edge"
}

assert_installer_chained() {
  assert_contains "install/config/all.sh" 'run_logged \$RYOKU_INSTALL/config/ryoku-resume-listener\.sh' \
    "Installer should be chained into install/config/all.sh so fresh installs enable the listener"
}

assert_migration_present() {
  assert_file "migrations/1777856216.sh"
  assert_contains "migrations/1777856216.sh" 'install/config/ryoku-resume-listener\.sh' \
    "Migration should re-invoke the listener installer for existing installs"
}

assert_listener_installer
assert_installer_chained
assert_listener_unit
assert_listener_script
assert_migration_present

echo "PASS: ryoku resume listener"
