#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

remote="$tmp/remote.git"
seed="$tmp/seed"
checkout="$tmp/checkout"
state_home="$tmp/state"
ryoku_state="$state_home/ryoku"
log="$tmp/update.log"

mkdir -p "$ryoku_state" "$state_home/quickshell/user"
printf '%s\n' "unstable-dev" >"$ryoku_state/channel"
printf '%s\n' "failed:1" >"$state_home/quickshell/user/update-status"
printf '%s\n' "update failed without a matched auto-fix" >"$log"

git init --bare "$remote" >/dev/null
git clone "$remote" "$seed" >/dev/null 2>&1
git -C "$seed" config user.email test@example.invalid
git -C "$seed" config user.name "Ryoku Test"
printf '%s\n' "main base" >"$seed/README.md"
git -C "$seed" add README.md
git -C "$seed" commit -m "main base" >/dev/null
git -C "$seed" push origin HEAD:main >/dev/null 2>&1
git -C "$seed" switch -q -c unstable-dev
printf '%s\n' "dev fix" >"$seed/dev.txt"
git -C "$seed" add dev.txt
git -C "$seed" commit -m "dev recovery fix" >/dev/null
git -C "$seed" push origin HEAD:unstable-dev >/dev/null 2>&1

git clone "$remote" "$checkout" >/dev/null 2>&1
git -C "$checkout" switch -q main

set +e
output=$(
  HOME="$tmp/home" \
  XDG_STATE_HOME="$state_home" \
  RYOKU_STATE_PATH="$ryoku_state" \
  RYOKU_PATH="$checkout" \
  RYOKU_UPDATE_REMOTE_URL="$remote" \
  RYOKU_UPDATE_LOG="$log" \
  RYOKU_DOCTOR_ASSUME_NO=1 \
  TMPDIR="$tmp" \
    "$ROOT_DIR/bin/ryoku-doctor" update 2>&1
)
status=$?
set -e

(( status != 0 )) || fail "doctor update should return non-zero when no auto-fix matches"

report_path="$(sed -n 's/.*Doctor report: //p' <<<"$output" | tail -1)"
[[ -f $report_path ]] || fail "doctor update report should exist"

grep -Fxq 'Release Branch: unstable-dev' "$report_path" || \
  fail "doctor report should follow the persisted update channel state"

grep -Fq 'A newer Ryoku recovery update is available' <<<"$output" || \
  fail "doctor should check the persisted update channel for recovery commits"

echo "PASS: ryoku-doctor follows persisted channel state"
