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

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

remote="$tmp/remote.git"
seed="$tmp/seed"
home="$tmp/home"
install="$home/.local/share/ryoku"
state="$home/.local/state/ryoku"
log="$tmp/bootstrap.log"

mkdir -p "$home/.local/bin" "$state"
git init --bare "$remote" >/dev/null
git clone "$remote" "$seed" >/dev/null 2>&1
git -C "$seed" config user.email test@example.invalid
git -C "$seed" config user.name "Ryoku Test"

mkdir -p "$seed/bin" "$seed/lib" "$seed/shell/scripts"
printf '%s\n' '# runtime env' > "$seed/lib/runtime-env.sh"
write_executable "$seed/bin/ryoku-update" '#!/bin/bash
set -euo pipefail
printf "fresh-update:%s\n" "$*" >> "$RYOKU_TEST_LOG"'
write_executable "$seed/bin/ryoku-doctor" '#!/bin/bash
exit 0'
write_executable "$seed/shell/scripts/ryoku-shell" '#!/bin/bash
exit 0'

git -C "$seed" add bin lib shell
git -C "$seed" commit -m "bootstrap payload" >/dev/null
git -C "$seed" push origin HEAD:main >/dev/null 2>&1
git -C "$seed" checkout -b unstable-dev >/dev/null 2>&1
printf '%s\n' "unstable bootstrap" > "$seed/unstable.txt"
git -C "$seed" add unstable.txt
git -C "$seed" commit -m "unstable bootstrap payload" >/dev/null
git -C "$seed" push origin HEAD:unstable-dev >/dev/null 2>&1

printf '%s\n' '# stale local doctor copy' > "$home/.local/bin/ryoku-doctor"
chmod 755 "$home/.local/bin/ryoku-doctor"

output=$(
  HOME="$home" \
  RYOKU_PATH="$install" \
  RYOKU_STATE_PATH="$state" \
  RYOKU_UPDATE_REMOTE_URL="$remote" \
  RYOKU_UPDATE_BRANCH=unstable-dev \
  RYOKU_TEST_LOG="$log" \
  PATH="/usr/bin:/bin" \
    "$ROOT_DIR/bin/ryoku-update-bootstrap" 2>&1
) || fail "bootstrap should clone, repair command bridges, and start refreshed updater: $output"

grep -Fq 'Ryoku bootstrap result:' <<< "$output" || \
  fail "bootstrap should print installed checkout provenance"
grep -Fq 'Channel: unstable-dev' <<< "$output" || \
  fail "bootstrap should use the requested update channel"
grep -Fq "Updater: $install/bin/ryoku-update" <<< "$output" || \
  fail "bootstrap should show the refreshed updater path"
grep -Fq 'fresh-update:-y' "$log" || \
  fail "bootstrap should exec the refreshed installed updater with -y"

[[ $(git -C "$install" branch --show-current) == "unstable-dev" ]] || \
  fail "bootstrap should leave the checkout on the requested branch"
grep -qx 'unstable bootstrap' "$install/unstable.txt" || \
  fail "bootstrap should install files from the requested branch"
[[ -L $home/.local/bin/ryoku-doctor ]] || \
  fail "bootstrap should replace stale local doctor copies with a checkout symlink"
[[ $(readlink "$home/.local/bin/ryoku-doctor") == "$install/bin/ryoku-doctor" ]] || \
  fail "bootstrap doctor shim should point to the installed checkout"
[[ -L $home/.local/lib/runtime-env.sh ]] || \
  fail "bootstrap should repair the local runtime-env bridge"

echo "PASS: ryoku-update-bootstrap repairs stale updater installs"

default_home="$tmp/default-home"
default_install="$default_home/.local/share/ryoku"
default_state="$default_home/.local/state/ryoku"
default_log="$tmp/default-bootstrap.log"

mkdir -p "$default_home/.local/bin" "$default_state"

output=$(
  HOME="$default_home" \
  RYOKU_PATH="$default_install" \
  RYOKU_STATE_PATH="$default_state" \
  RYOKU_UPDATE_REMOTE_URL="$remote" \
  RYOKU_TEST_LOG="$default_log" \
  PATH="/usr/bin:/bin" \
    "$ROOT_DIR/bin/ryoku-update-bootstrap" 2>&1
) || fail "bootstrap should default unconfigured rebirth recovery to unstable-dev: $output"

grep -Fq 'no Ryoku update channel configured; bootstrap is using unstable-dev' <<< "$output" || \
  fail "bootstrap should explain the rebirth recovery default channel"
grep -Fq 'Channel: unstable-dev' <<< "$output" || \
  fail "bootstrap should default to unstable-dev when no state or config channel exists"
[[ $(git -C "$default_install" branch --show-current) == "unstable-dev" ]] || \
  fail "unconfigured bootstrap should leave the checkout on unstable-dev"
grep -Fq 'fresh-update:-y' "$default_log" || \
  fail "unconfigured bootstrap should still exec the refreshed installed updater"

echo "PASS: ryoku-update-bootstrap defaults to rebirth recovery channel"
