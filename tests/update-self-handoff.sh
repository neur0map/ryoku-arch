#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

write_executable() {
  local path="$1"
  local content="$2"

  printf '%s\n' "$content" > "$path"
  chmod 755 "$path"
}

run_update() {
  HOME="$home" \
  RYOKU_PATH="$checkout" \
  RYOKU_STATE_PATH="$state" \
  RYOKU_UPDATE_LOGGED=1 \
  RYOKU_UPDATE_INHIBITED=1 \
  RYOKU_UPDATE_POWER_CHECKED=1 \
  RYOKU_TEST_LOG="$log" \
  PATH="$checkout/bin:$ROOT_DIR/bin:/usr/bin:/bin" \
    "$ROOT_DIR/bin/ryoku-update" "$@" 2>&1
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

home="$tmp/home"
checkout="$tmp/checkout"
state="$tmp/state"
log="$tmp/update.log"

mkdir -p \
  "$home/.local/bin" \
  "$checkout/bin" \
  "$checkout/lib" \
  "$checkout/shell/scripts" \
  "$state"

printf '%s\n' '# runtime env' > "$checkout/lib/runtime-env.sh"
write_executable "$checkout/shell/scripts/ryoku-shell" '#!/bin/bash
exit 0'

write_executable "$checkout/bin/ryoku-update" '#!/bin/bash
set -euo pipefail
printf "fresh:%s\n" "$*" >> "$RYOKU_TEST_LOG"
if [[ ${1:-} == "--resume-after-git" ]]; then
  echo "fresh updater resumed"
  exit 0
fi
exit 44'

write_executable "$checkout/bin/ryoku-update-git" '#!/bin/bash
set -euo pipefail
printf "git:%s\n" "$*" >> "$RYOKU_TEST_LOG"'

write_executable "$checkout/bin/ryoku-update-confirm" '#!/bin/bash
exit 1'

write_executable "$checkout/bin/ryoku-snapshot" '#!/bin/bash
echo "stale updater should not snapshot before refreshed handoff" >&2
exit 45'

write_executable "$checkout/bin/ryoku-update-perform" '#!/bin/bash
echo "stale updater should not perform before refreshed handoff" >&2
exit 46'

write_executable "$checkout/bin/ryoku-doctor" '#!/bin/bash
exit 0'

printf '%s\n' '# stale local doctor copy' > "$home/.local/bin/ryoku-doctor"
chmod 755 "$home/.local/bin/ryoku-doctor"

output="$(run_update -y)" || fail "ryoku-update should hand off to refreshed updater after git pull: $output"

grep -Fq 'Continuing through refreshed Ryoku updater:' <<< "$output" || \
  fail "update should explain that it is continuing through the refreshed updater"
grep -Fq 'fresh updater resumed' <<< "$output" || \
  fail "fresh updater should receive the --resume-after-git handoff"
grep -Fq 'git:' "$log" || \
  fail "update should run the git stage before the refreshed handoff"
grep -Fq 'fresh:--resume-after-git -y' "$log" || \
  fail "fresh updater should be called with resume marker and original -y flag"

[[ -L $home/.local/bin/ryoku-doctor ]] || \
  fail "update should replace stale local doctor copies with a Ryoku checkout symlink"
[[ $(readlink "$home/.local/bin/ryoku-doctor") == "$checkout/bin/ryoku-doctor" ]] || \
  fail "local ryoku-doctor shim should point at the installed checkout"
[[ -L $home/.local/lib/runtime-env.sh ]] || \
  fail "update should repair the local runtime-env bridge before continuing"

write_executable "$checkout/bin/ryoku-snapshot" '#!/bin/bash
set -euo pipefail
printf "snapshot:%s\n" "$*" >> "$RYOKU_TEST_LOG"'

write_executable "$checkout/bin/ryoku-update-perform" '#!/bin/bash
set -euo pipefail
printf "perform\n" >> "$RYOKU_TEST_LOG"'

: > "$log"
output="$(run_update --resume-after-git -y)" || fail "resume mode should run post-git stages exactly once: $output"

grep -Fq 'snapshot:create' "$log" || \
  fail "resume mode should create the update snapshot"
grep -Fq 'perform' "$log" || \
  fail "resume mode should run update-perform"
if grep -Fq 'git:' "$log"; then
  fail "resume mode should not run the git stage again"
fi

echo "PASS: ryoku-update hands off to refreshed updater"
