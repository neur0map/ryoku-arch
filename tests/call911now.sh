#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

link_tool() {
  local name="$1"
  local target

  target="$(command -v "$name")"
  ln -s "$target" "$tool_bin/$name"
}

write_executable() {
  local path="$1"
  local content="$2"

  printf '%s\n' "$content" >"$path"
  chmod 755 "$path"
}

[[ -x $ROOT_DIR/bin/ryoku-call911now ]] || \
  fail "ryoku-call911now should be executable"
grep -Fq '  ryoku-call911now' "$ROOT_DIR/bin/ryoku-call911now" || \
  fail "ryoku-call911now help should document the baked installed command form"
grep -Fq 'main/bin/ryoku-call911now | env RYOKU_UPDATE_BRANCH=main bash' "$ROOT_DIR/bin/ryoku-call911now" || \
  fail "ryoku-call911now help should document the main curl form with an explicit channel"
grep -Fq 'unstable-dev/bin/ryoku-call911now' "$ROOT_DIR/bin/ryoku-call911now" || \
  fail "ryoku-call911now help should document the rebirth unstable-dev curl form"
grep -Fq 'preflight_summary()' "$ROOT_DIR/bin/ryoku-call911now" || \
  fail "ryoku-call911now should show a preflight summary before rescue mutations"
grep -Fq 'may preserve and replace stale checkouts' "$ROOT_DIR/bin/ryoku-call911now" || \
  fail "ryoku-call911now should warn that MedEvac may replace stale checkouts"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

home="$tmp/home"
install="$home/.local/share/ryoku"
state="$home/.local/state/ryoku"
payload="$tmp/ryoku-arch-main"
archive="$tmp/ryoku-main.tar.gz"
tool_bin="$tmp/tools"
log="$tmp/medevac.log"

mkdir -p "$home/.local/bin" "$state" "$payload/bin" "$payload/lib" "$payload/shell/scripts" "$tool_bin"
printf '%s\n' '# runtime env' >"$payload/lib/runtime-env.sh"
write_executable "$payload/bin/ryoku-call911now" '#!/bin/bash
exit 0'
write_executable "$payload/bin/ryoku-doctor" '#!/bin/bash
printf "doctor:%s\n" "${RYOKU_PATH:-missing}" >> "$RYOKU_TEST_LOG"'
write_executable "$payload/bin/ryoku-update" '#!/bin/bash
printf "update:%s:%s\n" "${RYOKU_UPDATE_DOCTOR_COMMAND:-missing}" "$*" >> "$RYOKU_TEST_LOG"'
write_executable "$payload/shell/scripts/ryoku" '#!/bin/bash
exit 0'
write_executable "$payload/shell/scripts/ryoku-shell" '#!/bin/bash
exit 0'

tar -czf "$archive" -C "$tmp" "$(basename "$payload")"

for tool in basename cat chmod cp date dirname env find gzip head ln mkdir mktemp mv printf readlink rm rmdir tar; do
  link_tool "$tool"
done

cat >"$tool_bin/curl" <<'SH'
#!/bin/bash
output=""
while (($# > 0)); do
  case "$1" in
    -o)
      output="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

[[ -n $output ]] || exit 2
cp "$RYOKU_TEST_ARCHIVE" "$output"
SH
chmod 755 "$tool_bin/curl"

output=$(
  HOME="$home" \
  RYOKU_PATH="$install" \
  RYOKU_STATE_PATH="$state" \
  RYOKU_UPDATE_BRANCH=main \
  RYOKU_TEST_ARCHIVE="$archive" \
  RYOKU_TEST_LOG="$log" \
  RYOKU_MEDEVAC_ARCHIVE_BASE_URL="https://example.invalid" \
  PATH="$tool_bin" \
    "$ROOT_DIR/bin/ryoku-call911now" 2>&1
) || fail "medevac should recover from archive when git is unavailable: $output"

grep -Fq 'Ryoku MedEvac result:' <<<"$output" || \
  fail "medevac should print a final recovery result"
grep -Fq 'Archive fallback: used because git was unavailable' <<<"$output" || \
  fail "medevac should report the no-git archive fallback"
[[ -L $home/.local/lib/runtime-env.sh ]] || \
  fail "medevac should repair the local runtime-env bridge"
[[ $(readlink "$home/.local/lib/runtime-env.sh") == "$install/lib/runtime-env.sh" ]] || \
  fail "runtime-env bridge should point at the recovered checkout"
[[ -L $home/.local/bin/ryoku-call911now ]] || \
  fail "medevac should install its own baked command bridge"
grep -Fq "doctor:$install" "$log" || \
  fail "medevac should run the latest recovered doctor before update"
grep -Fq "update:$install/bin/ryoku-doctor:-y" "$log" || \
  fail "medevac should hand off to normal update with a path-safe doctor command"
[[ -r $state/last-medevac ]] || \
  fail "medevac should record the last recovery state for doctor/support follow-up"
grep -Fxq 'channel=main' "$state/last-medevac" || \
  fail "medevac state should record the recovered channel"
grep -Fxq 'archive_mode=1' "$state/last-medevac" || \
  fail "medevac state should record archive fallback use"
grep -Fxq 'doctor_status=0' "$state/last-medevac" || \
  fail "medevac state should record doctor status"
grep -Fxq 'update_status=0' "$state/last-medevac" || \
  fail "medevac state should record updater status"
grep -Fq 'preserved_backups=' "$state/last-medevac" || \
  fail "medevac state should record preserved checkout backup paths"

printf '%s\n' "PASS: ryoku-call911now medevac"
