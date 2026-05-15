#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

home_dir="$temp_dir/home"
ryoku_path="$temp_dir/ryoku"
log_file="$temp_dir/update-events.log"

mkdir -p "$home_dir" "$ryoku_path/bin"

cat >"$ryoku_path/bin/ryoku-snapshot" <<'SNAPSHOT'
#!/bin/bash
printf 'snapshot:%s\n' "$*" >>"$RYOKU_TEST_UPDATE_EVENTS"
exit 0
SNAPSHOT

cat >"$ryoku_path/bin/ryoku-update-git" <<'UPDATE_GIT'
#!/bin/bash
printf 'git\n' >>"$RYOKU_TEST_UPDATE_EVENTS"
exit "${RYOKU_TEST_UPDATE_GIT_STATUS:-0}"
UPDATE_GIT

cat >"$ryoku_path/bin/ryoku-update-perform" <<'PERFORM'
#!/bin/bash
printf 'perform\n' >>"$RYOKU_TEST_UPDATE_EVENTS"
exit 0
PERFORM

chmod +x "$ryoku_path/bin/ryoku-snapshot" \
  "$ryoku_path/bin/ryoku-update-git" \
  "$ryoku_path/bin/ryoku-update-perform"

run_update() {
  HOME="$home_dir" \
  RYOKU_PATH="$ryoku_path" \
  RYOKU_STATE_PATH="$temp_dir/state" \
  RYOKU_TEST_UPDATE_EVENTS="$log_file" \
  RYOKU_UPDATE_INHIBITED=1 \
  RYOKU_UPDATE_LOGGED=1 \
  RYOKU_UPDATE_POWER_CHECKED=1 \
  PATH="$ryoku_path/bin:$ROOT_DIR/bin:$PATH" \
  "$ROOT_DIR/bin/ryoku-update" -y
}

set +e
output=$(RYOKU_TEST_UPDATE_GIT_STATUS=42 run_update 2>&1)
status=$?
set -e

(( status == 42 )) || fail "ryoku-update should return the git update failure status, got $status: $output"
grep -qx 'git' "$log_file" || fail "ryoku-update should attempt the git update before failing"
! grep -q '^snapshot:' "$log_file" || fail "ryoku-update should not snapshot when git update fails"
! grep -qx 'perform' "$log_file" || fail "ryoku-update should not perform update stages when git update fails"

: >"$log_file"
output=$(run_update 2>&1) || fail "ryoku-update should finish when git update succeeds: $output"

mapfile -t events <"$log_file"
[[ ${events[0]:-} == "git" ]] || fail "git update should run before snapshot creation"
[[ ${events[1]:-} == "snapshot:create" ]] || fail "snapshot should be created after git update succeeds"
[[ ${events[2]:-} == "perform" ]] || fail "update stages should run after the snapshot"
(( ${#events[@]} == 3 )) || fail "unexpected extra update events: ${events[*]}"

echo "PASS: tests/update-snapshot-order.sh"
