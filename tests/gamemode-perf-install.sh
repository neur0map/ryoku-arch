#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() { # path pattern message
  grep -Eq "$2" "$ROOT_DIR/$1" || fail "$3"
}

[[ -x $ROOT_DIR/bin/ryoku-gamemode-perf ]] \
  || fail "bin/ryoku-gamemode-perf should exist and be executable"
[[ -f $ROOT_DIR/default/polkit/49-ryoku-gamemode.rules ]] \
  || fail "polkit rule default should exist"
[[ -x $ROOT_DIR/install/config/gamemode-perf.sh ]] \
  || fail "install/config/gamemode-perf.sh should exist and be executable"

assert_contains "default/polkit/49-ryoku-gamemode.rules" \
  'org\.freedesktop\.systemd1\.manage-units' \
  "polkit rule must scope to systemd manage-units"
assert_contains "default/polkit/49-ryoku-gamemode.rules" \
  'ryoku-gamemode-perf@\(full\|base\)' \
  "polkit rule must allow exactly the full/base unit instances"

assert_contains "install/config/gamemode-perf.sh" \
  'ryoku-gamemode-perf@\.service' \
  "install script must write the template unit"
assert_contains "install/config/gamemode-perf.sh" \
  'TimeoutStartSec=' \
  "template unit must bound ExecStart so a hung nvidia-smi cannot block it"
assert_contains "install/config/gamemode-perf.sh" \
  'daemon-reload' \
  "install script must reload systemd after writing the unit"

assert_contains "install/config/all.sh" \
  'config/gamemode-perf\.sh' \
  "gamemode-perf.sh must be registered in install/config/all.sh"

grep -RElq 'install/config/gamemode-perf\.sh' "$ROOT_DIR/migrations/" \
  || fail "a migration must ship the unit+polkit rule to existing installs"

echo "PASS: gamemode perf install plumbing"
