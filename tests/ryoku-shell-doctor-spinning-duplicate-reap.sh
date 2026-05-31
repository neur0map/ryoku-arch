#!/bin/bash

# A duplicate canonical Ryoku shell runtime whose event loop is saturated
# (the 100%-CPU spin) ignores the cooperative `qs kill` IPC quit, so the
# instances never die and pile up across restarts. The doctor must escalate
# to signal-reaping the surviving runtime PIDs.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  grep -Eq -- "$2" <<<"$1" || fail "$3"
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

home="$tmp/home"
runtime="$home/.config/quickshell/ryoku-shell"
bin_dir="$tmp/bin"
kill_log="$tmp/kill.log"
killed_pids="$tmp/killed-pids"
mkdir -p "$runtime" "$bin_dir"
: >"$kill_log"
: >"$killed_pids"

# qs stub: two canonical instances spinning on the same runtime. `qs kill`
# (cooperative IPC) "succeeds" but never removes them - the saturated event
# loop never processes the quit. `qs list` keeps reporting both PIDs.
cat >"$bin_dir/qs" <<EOF
#!/bin/bash
if [[ \${1:-} == "kill" ]]; then exit 0; fi
if [[ \${1:-} == "list" ]]; then
  cat <<LIST
Instance spin-a:
  Process ID: 123
  Config path: $runtime/shell.qml
  Display connection: wayland/wayland-test
Instance spin-b:
  Process ID: 789
  Config path: $runtime/shell.qml
  Display connection: wayland/wayland-test
LIST
  exit 0
fi
exit 0
EOF
chmod 755 "$bin_dir/qs"

cat >"$bin_dir/systemctl" <<'SH'
#!/bin/bash
[[ ${1:-} == "--user" && ${2:-} == "is-active" ]] && { echo active; exit 0; }
exit 0
SH
chmod 755 "$bin_dir/systemctl"

# Source the doctor (must be source-safe) and drive the single check in
# isolation. Overridden reporters capture FIX/FAIL; a fake kill records the
# signal and marks the PID dead so the liveness/identity check converges
# without touching real processes.
output="$(HOME="$home" XDG_CONFIG_HOME="$home/.config" RYOKU_SHELL_RUNTIME_DIR="$runtime" \
  RYOKU_QS_BIN="$bin_dir/qs" PATH="$bin_dir:/usr/bin:/bin" \
  bash -c '
set -euo pipefail
source "'"$ROOT_DIR"'/shell/scripts/ryoku-shell-doctor"
doctor_pass() { echo "OK: $*"; }
doctor_warn() { echo "WARN: $*"; }
doctor_fix()  { echo "FIX: $*"; }
doctor_fail() { echo "FAIL: $*"; }
sleep() { :; }
kill() { printf "%s %s\n" "${1:-}" "${2:-}" >> "'"$kill_log"'"; printf "%s\n" "${2:-}" >> "'"$killed_pids"'"; }
pid_is_our_shell() { local p="$1"; grep -qxF "$p" "'"$killed_pids"'" && return 1; case "$p" in 123|789) return 0;; *) return 1;; esac; }
check_quickshell_instance
' 2>&1)"

kills="$(<"$kill_log")"

assert_contains "$kills" '(^| )123$' \
  "doctor should signal-reap surviving canonical runtime PID 123 that ignored the cooperative quit"
assert_contains "$kills" '(^| )789$' \
  "doctor should signal-reap surviving canonical runtime PID 789 that ignored the cooperative quit"
assert_contains "$output" 'FIX:.*([Uu]nresponsive|[Ff]orce)' \
  "doctor should report force-stopping the unresponsive duplicate runtime"
assert_contains "$output" 'FIX: Restarted ryoku-shell.service to collapse duplicate Ryoku bars' \
  "doctor should restart the service after collapsing duplicates"

echo "PASS: ryoku-shell-doctor-spinning-duplicate-reap"
