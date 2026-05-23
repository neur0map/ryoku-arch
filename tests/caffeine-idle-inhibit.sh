#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
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

idle_service="shell/services/IdleInhibitor.qml"
idle_monitors="shell/modules/IdleMonitors.qml"
caffeine_cmd="bin/ryoku-cmd-caffeine"
shell_root="shell/shell.qml"

[[ -f $idle_service ]] || fail "$idle_service missing"
[[ -f $idle_monitors ]] || fail "$idle_monitors missing"
[[ -f $caffeine_cmd ]] || fail "$caffeine_cmd missing"
[[ -f $shell_root ]] || fail "$shell_root missing"

assert_contains "$shell_root" 'import qs\.services' \
  "shell startup should import services so stay awake can be restored immediately"
assert_contains "$shell_root" 'IdleInhibitor\.enabled' \
  "shell startup should instantiate the stay-awake service"

assert_contains "$idle_service" 'ryoku-cmd-caffeine' \
  "the UI should route caffeine through the shared helper"
assert_contains "$idle_service" '"ryoku-cmd-caffeine", "restore"' \
  "shell startup should restore a persisted caffeine request"
assert_contains "$idle_service" '"ryoku-cmd-caffeine", "start"' \
  "enabling stay awake should call the caffeine helper"
assert_contains "$idle_service" '"ryoku-cmd-caffeine", "stop"' \
  "disabling stay awake should call the caffeine helper"
assert_contains "$idle_service" '"ryoku-cmd-caffeine", "status"' \
  "the UI should reconcile with the actual caffeine helper state"
assert_not_contains "$idle_service" 'systemd-inhibit' \
  "the UI should not own the long-lived inhibitor process"
assert_not_contains "$idle_service" 'import Quickshell\.Wayland' \
  "stay awake should not depend on a shell-owned Wayland idle inhibitor"
assert_not_contains "$idle_service" '^[[:space:]]*IdleInhibitor[[:space:]]*\{' \
  "stay awake should not be tied to a shell-owned Wayland idle inhibitor object"
assert_not_contains "$idle_service" '_idleInhibitorAllowed|id: _idleInhibitor|running: root\.inhibit' \
  "caffeine should not be tied to the Quickshell process lifetime"
assert_not_contains "$idle_service" 'Component\.onDestruction:[^}]*ryoku-cmd-caffeine[^}]*stop' \
  "shell shutdown should not turn off a persisted caffeine request"
assert_contains "$idle_monitors" '!IdleInhibitor\.enabled' \
  "Ryoku idle monitors should pause while stay-awake mode is enabled"
assert_contains "$idle_monitors" 'IdleInhibitor\.enabled' \
  "Ryoku idle monitors should include stay-awake state in their enabled guard"

assert_contains "$caffeine_cmd" 'state_file=' \
  "caffeine helper should persist the user's requested stay-awake state"
assert_contains "$caffeine_cmd" 'RYOKU_CAFFEINE_STATE_FILE' \
  "caffeine helper should expose an overrideable state file for tests"
assert_contains "$caffeine_cmd" 'restore_caffeine' \
  "caffeine helper should restore a persisted stay-awake request"
assert_contains "$caffeine_cmd" '--what=idle' \
  "caffeine helper should inhibit system idle"
assert_not_contains "$caffeine_cmd" '--what=idle:sleep' \
  "caffeine helper should not block explicit sleep requests"
assert_contains "$caffeine_cmd" 'ryoku-caffeine-inhibit' \
  "caffeine helper status should track the same inhibitor it starts"
assert_contains "$caffeine_cmd" 'legacy_inhibit_pattern=' \
  "caffeine helper should clean the old QML-owned inhibitor during migration"
assert_contains "$caffeine_cmd" 'flock -x' \
  "caffeine helper should serialize start/stop so shell startup cannot spawn duplicate inhibitors"
assert_contains "$caffeine_cmd" '9>&-' \
  "caffeine helper should not leak the serialization lock into the background inhibitor"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

stub_bin="$tmp_dir/bin"
state_file="$tmp_dir/caffeine.state"
lock_file="$tmp_dir/caffeine.lock"
marker="$tmp_dir/inhibitor.active"
mkdir -p "$stub_bin"

cat >"$stub_bin/pgrep" <<'STUB'
#!/bin/bash
if [[ -f ${RYOKU_TEST_CAFFEINE_MARKER:?} ]]; then
  exit 0
fi
exit 1
STUB

cat >"$stub_bin/pkill" <<'STUB'
#!/bin/bash
rm -f "${RYOKU_TEST_CAFFEINE_MARKER:?}"
exit 0
STUB

cat >"$stub_bin/setsid" <<'STUB'
#!/bin/bash
touch "${RYOKU_TEST_CAFFEINE_MARKER:?}"
exit 0
STUB

chmod +x "$stub_bin/pgrep" "$stub_bin/pkill" "$stub_bin/setsid"

PATH="$stub_bin:$PATH" \
RYOKU_CAFFEINE_STATE_FILE="$state_file" \
RYOKU_CAFFEINE_LOCK_FILE="$lock_file" \
RYOKU_TEST_CAFFEINE_MARKER="$marker" \
bash "$caffeine_cmd" start

[[ -f $state_file ]] || fail "start should persist the enabled stay-awake state"
[[ -f $marker ]] || fail "start should launch the idle inhibitor"

rm -f "$marker"

PATH="$stub_bin:$PATH" \
RYOKU_CAFFEINE_STATE_FILE="$state_file" \
RYOKU_CAFFEINE_LOCK_FILE="$lock_file" \
RYOKU_TEST_CAFFEINE_MARKER="$marker" \
bash "$caffeine_cmd" restore

[[ -f $marker ]] || fail "restore should restart the idle inhibitor when stay-awake is persisted"

PATH="$stub_bin:$PATH" \
RYOKU_CAFFEINE_STATE_FILE="$state_file" \
RYOKU_CAFFEINE_LOCK_FILE="$lock_file" \
RYOKU_TEST_CAFFEINE_MARKER="$marker" \
bash "$caffeine_cmd" stop

[[ ! -f $state_file ]] || fail "stop should clear the persisted stay-awake state"
[[ ! -f $marker ]] || fail "stop should clear the idle inhibitor"

echo "OK: caffeine idle inhibit contract"
