#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
REPAIR="$ROOT_DIR/bin/ryoku-update-repair-branch"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

remote="$tmp/remote.git"
seed="$tmp/seed"
checkout="$tmp/checkout"
state_dir="$tmp/state"

mkdir -p "$state_dir"

[[ -x $REPAIR ]] || fail "repair command should exist and be executable"

git init --bare "$remote" >/dev/null
git clone "$remote" "$seed" >/dev/null 2>&1
git -C "$seed" config user.email test@example.invalid
git -C "$seed" config user.name "Ryoku Test"
printf '%s\n' "base" >"$seed/README.md"
git -C "$seed" add README.md
git -C "$seed" commit -m "base" >/dev/null
base_commit="$(git -C "$seed" rev-parse HEAD)"

printf '%s\n' "old official content" >"$seed/old-official.txt"
git -C "$seed" add old-official.txt
git -C "$seed" commit -m "old official branch tip" >/dev/null
git -C "$seed" push origin HEAD:main >/dev/null 2>&1

git clone "$remote" "$checkout" >/dev/null 2>&1
git -C "$checkout" checkout main >/dev/null 2>&1

printf '%s\n' "old official refresh" >"$seed/old-official-refresh.txt"
git -C "$seed" add old-official-refresh.txt
git -C "$seed" commit -m "old official refresh" >/dev/null
git -C "$seed" push origin HEAD:main >/dev/null 2>&1
git -C "$checkout" fetch origin "+refs/heads/main:refs/remotes/origin/main" >/dev/null 2>&1
git -C "$checkout" branch unstable-dev origin/main
git -C "$checkout" branch --set-upstream-to origin/unstable-dev unstable-dev >/dev/null 2>&1 || true

git -C "$seed" reset --hard "$base_commit" >/dev/null
printf '%s\n' "new main content" >"$seed/main-rewritten.txt"
git -C "$seed" add main-rewritten.txt
git -C "$seed" commit -m "rewritten main branch" >/dev/null
git -C "$seed" push --force origin HEAD:main >/dev/null 2>&1
git -C "$seed" reset --hard "$base_commit" >/dev/null
git -C "$seed" checkout -B unstable-dev >/dev/null 2>&1
printf '%s\n' "new dev content" >"$seed/dev-rewritten.txt"
git -C "$seed" add dev-rewritten.txt
git -C "$seed" commit -m "rewritten dev branch" >/dev/null
git -C "$seed" push --force origin HEAD:unstable-dev >/dev/null 2>&1

git -C "$checkout" switch -q unstable-dev
git -C "$checkout" fetch --prune origin \
  "+refs/heads/main:refs/remotes/origin/main" \
  "+refs/heads/unstable-dev:refs/remotes/origin/unstable-dev" >/dev/null 2>&1

set +e
ff_output="$(git -C "$checkout" merge --ff-only origin/unstable-dev 2>&1)"
ff_status=$?
set -e

(( ff_status != 0 )) || fail "test setup should reproduce the ff-only failure"
grep -Fq "Not possible to fast-forward" <<<"$ff_output" || \
  fail "test setup should match the user-facing ff-only failure"

repair_output="$(
  RYOKU_PATH="$checkout" \
  RYOKU_STATE_PATH="$state_dir" \
  RYOKU_UPDATE_REMOTE_URL="$remote" \
    "$REPAIR" unstable-dev 2>&1
)" || fail "repair command should unstick old official branch history: $repair_output"

grep -Fq "Realigned Ryoku unstable-dev to origin/unstable-dev" <<<"$repair_output" || \
  fail "repair command should explain the branch realignment"

[[ $(git -C "$checkout" branch --show-current) == "unstable-dev" ]] || \
  fail "repair command should leave the checkout on unstable-dev"
[[ $(git -C "$checkout" rev-parse HEAD) == "$(git -C "$seed" rev-parse unstable-dev)" ]] || \
  fail "repair command should move the branch to origin/unstable-dev"
grep -qx "new dev content" "$checkout/dev-rewritten.txt" || \
  fail "repair command should check out the selected channel content"
[[ ! -e $checkout/old-official.txt ]] || \
  fail "repair command should remove old tracked branch content"

git -C "$checkout" merge --ff-only origin/unstable-dev >/dev/null 2>&1 || \
  fail "checkout should no longer be stuck after repair"

unsafe_checkout="$tmp/unsafe-checkout"
git clone "$remote" "$unsafe_checkout" >/dev/null 2>&1
git -C "$unsafe_checkout" checkout unstable-dev >/dev/null 2>&1
git -C "$unsafe_checkout" config user.email test@example.invalid
git -C "$unsafe_checkout" config user.name "Ryoku Test"
printf '%s\n' "personal local commit" >"$unsafe_checkout/local-only.txt"
git -C "$unsafe_checkout" add local-only.txt
git -C "$unsafe_checkout" commit -m "personal local commit" >/dev/null
unsafe_head="$(git -C "$unsafe_checkout" rev-parse HEAD)"

set +e
unsafe_output="$(
  RYOKU_PATH="$unsafe_checkout" \
  RYOKU_STATE_PATH="$state_dir" \
  RYOKU_UPDATE_REMOTE_URL="$remote" \
    "$REPAIR" unstable-dev 2>&1
)"
unsafe_status=$?
set -e

(( unsafe_status != 0 )) || fail "repair command should refuse real local commits"
[[ $(git -C "$unsafe_checkout" rev-parse HEAD) == "$unsafe_head" ]] || \
  fail "repair command should not move arbitrary local commits"
grep -Fq "does not look like old official Ryoku history" <<<"$unsafe_output" || \
  fail "repair command should explain why arbitrary local commits are refused"

echo "PASS: update stale branch repair"
