#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

bin_dir="$tmp/bin"
state="$tmp/state"
gum_log="$tmp/gum.log"

mkdir -p "$bin_dir" "$state"
cat >"$state/last-update" <<'STATE'
updated_at=2026-05-24T00:00:00Z
checkout=unstable-dev@abc1234
remote_tip=origin/unstable-dev@abc1234
active_doctor=/tmp/ryoku/bin/ryoku-doctor
gum=/tmp/bin/gum
STATE

cat >"$bin_dir/gum" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >>"$RYOKU_GUM_LOG"
exit 0
SH
chmod 755 "$bin_dir/gum"

set +e
output=$(
  HOME="$tmp/home" \
  RYOKU_PATH="$ROOT_DIR" \
  RYOKU_STATE_PATH="$state" \
  RYOKU_GUM_LOG="$gum_log" \
  PATH="$bin_dir:$ROOT_DIR/bin:/usr/bin:/bin" \
    "$ROOT_DIR/bin/ryoku-doctor" update 2>&1
)
status=$?
set -e

(( status != 0 )) || fail "doctor update should fail when no update log is available"
grep -Fq 'gum is available but stdout is not interactive' <<<"$output" || \
  fail "non-interactive doctor should explain why gum UI is not rendered: $output"
grep -Fq 'Last update: 2026-05-24T00:00:00Z unstable-dev@abc1234 remote=origin/unstable-dev@abc1234' <<<"$output" || \
  fail "doctor context should preserve the last update remote tip proof: $output"
grep -Fq "Run: $ROOT_DIR/bin/ryoku-doctor" <<<"$output" || \
  fail "doctor update recovery should point at the installed doctor path"
[[ ! -s $gum_log ]] || \
  fail "non-interactive doctor should not invoke gum unless pretty mode is forced"

echo "PASS: ryoku-doctor explains non-interactive plain output"
