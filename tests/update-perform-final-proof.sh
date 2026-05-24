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

  printf '%s\n' "$content" >"$path"
  chmod 755 "$path"
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

home="$tmp/home"
ryoku="$tmp/ryoku"
state="$tmp/state"
events="$tmp/events.log"
bin_dir="$tmp/bin"
remote="$tmp/remote.git"

mkdir -p \
  "$home/.local/lib" \
  "$ryoku/bin" \
  "$ryoku/install/packaging" \
  "$ryoku/install/config" \
  "$state" \
  "$bin_dir"

printf '%s\n' '# runtime env' >"$ryoku/lib-runtime-env.sh"
ln -sfn "$ryoku/lib-runtime-env.sh" "$home/.local/lib/runtime-env.sh"

write_executable "$ryoku/bin/ryoku-doctor" '#!/bin/bash
exit 0'
write_executable "$bin_dir/gum" '#!/bin/bash
exit 0'

git init --bare "$remote" >/dev/null
git -C "$ryoku" init >/dev/null
git -C "$ryoku" config user.email test@example.invalid
git -C "$ryoku" config user.name "Ryoku Test"
git -C "$ryoku" commit --allow-empty -m "installed checkout" >/dev/null
git -C "$ryoku" switch -c unstable-dev >/dev/null 2>&1
git -C "$ryoku" remote add origin "$remote"
git -C "$ryoku" push origin unstable-dev >/dev/null 2>&1

for command in \
  ryoku-cmd-caffeine \
  ryoku-migrate \
  ryoku-update-keyring \
  ryoku-update-available-reset \
  ryoku-update-system-pkgs \
  ryoku-update-aur-pkgs \
  ryoku-update-orphan-pkgs \
  ryoku-hook \
  ryoku-update-analyze-logs \
  ryoku-update-restart; do
  write_executable "$ryoku/bin/$command" '#!/bin/bash
printf "%s:%s\n" "$(basename "$0")" "$*" >>"$RYOKU_TEST_UPDATE_EVENTS"
exit 0'
done

for script in \
  "$ryoku/install/packaging/base.sh" \
  "$ryoku/install/packaging/aur-core.sh" \
  "$ryoku/install/packaging/distro-arch.sh" \
  "$ryoku/install/config/shell.sh"; do
  write_executable "$script" '#!/bin/bash
printf "%s\n" "$0" >>"$RYOKU_TEST_UPDATE_EVENTS"
exit 0'
done

output=$(
  HOME="$home" \
  RYOKU_PATH="$ryoku" \
  RYOKU_STATE_PATH="$state" \
  RYOKU_TEST_UPDATE_EVENTS="$events" \
  RYOKU_UPDATE_DASHBOARD=0 \
  PATH="$ryoku/bin:$bin_dir:/usr/bin:/bin" \
    "$ROOT_DIR/bin/ryoku-update-perform" 2>&1
) || fail "update performer should finish with stubbed stages: $output"

grep -Fq 'Ryoku update result:' <<<"$output" || \
  fail "successful update should print final provenance after all update stages"
grep -Fq 'Channel: unstable-dev' <<<"$output" || \
  fail "final update provenance should preserve the installed checkout channel"
remote_tip="$(git -C "$ryoku" rev-parse --short origin/unstable-dev)"
grep -Fq "Remote tip: origin/unstable-dev@$remote_tip" <<<"$output" || \
  fail "final update provenance should show the selected remote tip"
grep -Fq "Expected doctor: $ryoku/bin/ryoku-doctor" <<<"$output" || \
  fail "final update provenance should show the installed doctor path"
grep -Fq "Active doctor: $ryoku/bin/ryoku-doctor" <<<"$output" || \
  fail "final update provenance should resolve doctor from the installed checkout"
grep -Fq "Gum: $bin_dir/gum" <<<"$output" || \
  fail "final update provenance should record post-package gum availability"
grep -Fq "Runtime bridge: $home/.local/lib/runtime-env.sh -> $ryoku/lib-runtime-env.sh" <<<"$output" || \
  fail "final update provenance should record the runtime bridge after updates"

last_update="$state/last-update"
[[ -f $last_update ]] || fail "successful update should persist final provenance"
grep -Fxq "gum=$bin_dir/gum" "$last_update" || \
  fail "persisted update provenance should record post-package gum availability"
grep -Fxq "channel=unstable-dev" "$last_update" || \
  fail "persisted update provenance should preserve the installed checkout channel"
grep -Fxq "remote_tip=origin/unstable-dev@$remote_tip" "$last_update" || \
  fail "persisted update provenance should record the selected remote tip"
grep -Fxq "active_doctor=$ryoku/bin/ryoku-doctor" "$last_update" || \
  fail "persisted update provenance should record the installed doctor path"
grep -Fq 'ryoku-cmd-caffeine:hold' "$events" || \
  fail "update performer should use a temporary idle hold instead of mutating the Stay Awake setting"
grep -Fq 'ryoku-cmd-caffeine:release' "$events" || \
  fail "update performer should release the temporary idle hold when finished"
if grep -Eq 'ryoku-cmd-caffeine:(start|stop)' "$events"; then
  fail "update performer should not start/stop the persisted Stay Awake setting"
fi

previous_head="$(git -C "$ryoku" rev-parse HEAD)"
printf '%s\n' "remote-only update" >"$ryoku/remote-only.txt"
git -C "$ryoku" add remote-only.txt
git -C "$ryoku" commit -m "remote-only update" >/dev/null
git -C "$ryoku" push origin unstable-dev >/dev/null 2>&1
git -C "$ryoku" fetch origin "+refs/heads/unstable-dev:refs/remotes/origin/unstable-dev" >/dev/null 2>&1
git -C "$ryoku" reset --hard "$previous_head" >/dev/null

output=$(
  HOME="$home" \
  RYOKU_PATH="$ryoku" \
  RYOKU_STATE_PATH="$state" \
  RYOKU_TEST_UPDATE_EVENTS="$events" \
  RYOKU_UPDATE_DASHBOARD=0 \
  PATH="$ryoku/bin:$bin_dir:/usr/bin:/bin" \
    "$ROOT_DIR/bin/ryoku-update-perform" 2>&1
) || fail "update performer should still finish with stubbed stages on mismatched proof: $output"

grep -Fq 'Warning: checkout does not match the selected remote tip' <<<"$output" || \
  fail "final update provenance should warn when checkout and remote tip differ: $output"

echo "PASS: update performer records final Ryoku provenance"
