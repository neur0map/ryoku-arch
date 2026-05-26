#!/bin/bash

set -euo pipefail

# Regression guard for the "100% volume but silent speakers" symptom.
#
# install/config/hardware/fix-audio-mixer.sh runs once at install time and
# unmutes Master/Speaker/Headphone/Bass Speaker/PCM. But the mixer can be
# reset back to silent defaults by suspend, audio-profile switches, or
# codec power transitions - leaving the user with a working PipeWire
# graph that produces no audible sound.
#
# ryoku-audio-restore-mixers (helper) + ryoku-audio-restore-mixers.service
# (systemd-user unit) re-run the unmute loop on every login as a
# self-healing guard. This test enforces:
#   1. The helper exists, is executable, and contains the unmute loop.
#   2. The systemd-user unit exists with the right target wiring.
#   3. The installer is wired into install/config/all.sh.
#   4. fix-audio-mixer.sh delegates to the shared helper (single source
#      of truth - if someone edits the helper, install-time and per-login
#      behavior stay in sync).

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_not_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  if grep -Eq "$pattern" "$path"; then
    fail "$message"
  fi
}

helper="$ROOT_DIR/bin/ryoku-audio-restore-mixers"
[[ -x $helper ]] || fail "missing or non-executable bin/ryoku-audio-restore-mixers"

grep -qE 'amixer -c "\$card" set "\$ctl" 100% unmute' "$helper" || \
  fail "ryoku-audio-restore-mixers must unmute each control to 100% via amixer"

grep -qE 'Speaker.*Headphone.*Bass Speaker' "$helper" || \
  fail "ryoku-audio-restore-mixers must cover Speaker, Headphone, and Bass Speaker controls"

unit="$ROOT_DIR/config/systemd/user/ryoku-audio-restore-mixers.service"
migration="$ROOT_DIR/migrations/1779815059.sh"
[[ -f $unit ]] || fail "missing config/systemd/user/ryoku-audio-restore-mixers.service"

grep -qE '^ExecStart=.*ryoku-audio-restore-mixers$' "$unit" || \
  fail "service unit must ExecStart the ryoku-audio-restore-mixers helper"

grep -qE '^WantedBy=default.target$' "$unit" || \
  fail "service unit must be WantedBy=default.target so Hyprland sessions without graphical-session.target still run it"

grep -qE '^After=pipewire\.service$' "$unit" || \
  fail "service unit must order After=pipewire.service so amixer hits a live audio stack"

assert_not_contains "$unit" 'graphical-session\.target' \
  "audio mixer self-heal must not depend on graphical-session.target, which is inactive in Ryoku Hyprland sessions"

[[ -f $migration ]] || fail "missing migration to retarget existing audio restore service installs"
grep -qE 'install/config/ryoku-audio-restore-mixers\.sh' "$migration" || \
  fail "migration must reinstall the audio mixer restore user service for existing installs"
grep -qE 'ryoku-audio-restore-mixers' "$migration" || \
  fail "migration must immediately restore mixers so current silent sessions recover"

installer="$ROOT_DIR/install/config/ryoku-audio-restore-mixers.sh"
[[ -x $installer ]] || fail "missing or non-executable install/config/ryoku-audio-restore-mixers.sh"

grep -qE 'systemctl --user disable ryoku-audio-restore-mixers\.service' "$installer" || \
  fail "installer must disable stale target links before enabling the audio restore service"

grep -qE 'systemctl --user enable --now ryoku-audio-restore-mixers\.service' "$installer" || \
  fail "installer must enable --now the systemd-user unit"

dispatcher="$ROOT_DIR/install/config/all.sh"
grep -qF '$RYOKU_INSTALL/config/ryoku-audio-restore-mixers.sh' "$dispatcher" || \
  fail "install/config/all.sh must call ryoku-audio-restore-mixers.sh so new installs enable the self-heal service"

# Single source of truth: the install-time mixer fixer should delegate to the
# helper rather than duplicating the unmute loop.
fixer="$ROOT_DIR/install/config/hardware/fix-audio-mixer.sh"
grep -qE '\$RYOKU_PATH/bin/ryoku-audio-restore-mixers' "$fixer" || \
  fail "install/config/hardware/fix-audio-mixer.sh must delegate the unmute loop to bin/ryoku-audio-restore-mixers (avoid drift)"

if grep -qE 'amixer.*set.*100%.*unmute' "$fixer"; then
  fail "install/config/hardware/fix-audio-mixer.sh must not duplicate the amixer unmute loop - delegate to ryoku-audio-restore-mixers instead"
fi

echo "PASS: ryoku-audio-restore-mixers wired into install + login flow"
