#!/bin/bash

set -euo pipefail

# Regression guard for the three critical checks the shell doctor must
# carry post-rebirth. Each one corresponds to a real bug that surfaced
# during the Hyprland + Caelestia rebirth move:
#
#   1. Native plugin loadability - the Ryoku Services QML plugin
#      (libryoku-services.so) must exist and be linked against libcava.
#      Without libcava, CavaProcessor compiles out and the dashboard
#      music visualiser bars clamp to 1e-3 px (invisible). This check
#      would have caught that silent regression at install time.
#
#   2. Audio mixer self-heal service - ryoku-audio-restore-mixers.service
#      must be enabled. Without it, codec power transitions / profile
#      switches / suspend can reset Speaker+Headphone to muted-and-zero
#      and the user gets "100% volume but silent speakers" with a clean
#      PipeWire graph.
#
#   3. Stale Niri service wiring cleanup - pre-rebirth installs may have
#      ~/.config/systemd/user/niri.service.wants/ryoku-shell.service
#      symlinks that point at a compositor we no longer ship. The
#      doctor must clean these up so the rebirth -> main merge doesn't
#      leave stranded service references.
#
# Also enforces that the bin/ryoku-doctor fallback no longer hunts for
# the obsolete ~/.config/ryoku-shell/setup path (post-rebirth the only
# valid setup locations are the runtime mirror and the repo).

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

shell_doctor="$ROOT_DIR/shell/scripts/ryoku-shell-doctor"
[[ -f $shell_doctor ]] || fail "missing shell/scripts/ryoku-shell-doctor"

grep -qE 'check_native_plugin\(\)' "$shell_doctor" || \
  fail "shell-doctor must define check_native_plugin to verify libryoku-services.so loads + links libcava"

grep -qE 'libryoku-services\.so' "$shell_doctor" || \
  fail "shell-doctor must reference libryoku-services.so by name in the native-plugin check"

grep -qE "libcava\\\\\\.so" "$shell_doctor" || \
  fail "shell-doctor must verify libcava is linked into the plugin (catches the dashboard visualiser silent-regression class)"

grep -qE 'check_audio_restore_service\(\)' "$shell_doctor" || \
  fail "shell-doctor must define check_audio_restore_service to verify ryoku-audio-restore-mixers.service is enabled"

grep -qE 'ryoku-audio-restore-mixers\.service' "$shell_doctor" || \
  fail "shell-doctor must reference ryoku-audio-restore-mixers.service by name"

grep -qE 'check_stale_compositor_wiring\(\)' "$shell_doctor" || \
  fail "shell-doctor must keep check_stale_compositor_wiring (cleans up niri.service.wants symlinks)"

# Verify all three checks are actually wired into run_shell_doctor's
# pipeline, not just defined as dead functions.
for check_name in check_native_plugin check_audio_restore_service check_stale_compositor_wiring; do
  grep -qE "run_check.*$check_name" "$shell_doctor" || \
    fail "shell-doctor's run_shell_doctor must invoke $check_name via run_check"
done

ryoku_doctor="$ROOT_DIR/bin/ryoku-doctor"
[[ -f $ryoku_doctor ]] || fail "missing bin/ryoku-doctor"

if grep -qE 'XDG_CONFIG_HOME.*}/ryoku-shell/setup' "$ryoku_doctor"; then
  fail "bin/ryoku-doctor must not search ~/.config/ryoku-shell/setup as a shell-doctor candidate (path is obsolete post-rebirth)"
fi

echo "PASS: shell doctor carries the three rebirth-critical checks (native plugin, audio self-heal, stale compositor wiring)"
