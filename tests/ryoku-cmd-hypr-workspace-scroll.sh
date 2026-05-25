#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

fake_bin="$tmp_dir/bin"
dispatch_log="$tmp_dir/dispatch.log"
state_dir="$tmp_dir/state"
mkdir -p "$fake_bin"

cat > "$fake_bin/hyprctl" <<'HYPRCTL'
#!/bin/bash

set -euo pipefail

if [[ ${1:-} == "activeworkspace" && ${2:-} == "-j" ]]; then
  printf '{"id":%s,"name":"%s"}\n' "${ACTIVE_ID:-2}" "${ACTIVE_ID:-2}"
elif [[ ${1:-} == "workspaces" && ${2:-} == "-j" ]]; then
  printf '[{"id":1,"name":"1"},{"id":2,"name":"2"},{"id":3,"name":"3"},{"id":-99,"name":"special:term"}]\n'
elif [[ ${1:-} == "dispatch" && ${2:-} == "workspace" ]]; then
  printf '%s\n' "${3:-}" >> "$HYPR_DISPATCH_LOG"
else
  exit 2
fi
HYPRCTL
chmod +x "$fake_bin/hyprctl"

run_scroll() {
  : > "$dispatch_log"
  rm -rf "$state_dir"
  ACTIVE_ID="$1" HYPR_DISPATCH_LOG="$dispatch_log" PATH="$fake_bin:$PATH" \
    RYOKU_WORKSPACE_SCROLL_STATE_DIR="$state_dir" \
    "$ROOT_DIR/bin/ryoku-cmd-hypr-workspace-scroll" "$2"
}

run_scroll_at() {
  ACTIVE_ID="$1" HYPR_DISPATCH_LOG="$dispatch_log" PATH="$fake_bin:$PATH" \
    RYOKU_WORKSPACE_SCROLL_STATE_DIR="$state_dir" \
    RYOKU_WORKSPACE_SCROLL_NOW_MS="$3" \
    RYOKU_WORKSPACE_SCROLL_INTERVAL_MS=420 \
    "$ROOT_DIR/bin/ryoku-cmd-hypr-workspace-scroll" "$2"
}

run_scroll 2 next
[[ $(<"$dispatch_log") == "3" ]] || fail "next should dispatch the next open workspace"

run_scroll 2 prev
[[ $(<"$dispatch_log") == "1" ]] || fail "prev should dispatch the previous open workspace"

run_scroll 3 next
[[ ! -s $dispatch_log ]] || fail "next should stop at the last open workspace"

run_scroll 1 prev
[[ ! -s $dispatch_log ]] || fail "prev should stop at the first open workspace"

rm -rf "$state_dir"
: > "$dispatch_log"
run_scroll_at 2 next 1000
run_scroll_at 2 next 1300
[[ $(wc -l < "$dispatch_log") == "1" ]] || fail "rapid scroll ticks should be swallowed by the helper debounce"
run_scroll_at 2 next 1450
[[ $(wc -l < "$dispatch_log") == "2" ]] || fail "scroll debounce should allow the next dispatch after the interval"

if "$ROOT_DIR/bin/ryoku-cmd-hypr-workspace-scroll" sideways >/dev/null 2>&1; then
  fail "invalid direction should fail"
fi

echo "PASS: ryoku-cmd-hypr-workspace-scroll stops at open workspace edges"
