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
home="$tmp/home"
state="$tmp/state"

mkdir -p "$bin_dir" "$home" "$state"
cat >"$bin_dir/sudo" <<'SH'
#!/bin/bash
if [[ ${1:-} == "-n" ]]; then
  exit 1
fi
printf 'sudo should not be asked from this non-TTY test\n' >&2
exit 1
SH
cat >"$bin_dir/script" <<'SH'
#!/bin/bash
printf 'script should not run before sudo terminal preflight\n' >&2
exit 9
SH
chmod 755 "$bin_dir/sudo" "$bin_dir/script"

set +e
output=$(
  HOME="$home" \
  RYOKU_STATE_PATH="$state" \
  PATH="$bin_dir:/usr/bin:/bin" \
    "$ROOT_DIR/bin/ryoku-update" -y </dev/null 2>&1
)
status=$?
set -e

(( status != 0 )) || fail "non-TTY update should fail before sudo can time out"
grep -Fq 'Ryoku update needs sudo authentication, but stdin is not a terminal.' <<<"$output" || \
  fail "update should explain the missing terminal stdin: $output"
grep -Fq 'Run from a real terminal, or run sudo -v first and retry: ryoku-update -y' <<<"$output" || \
  fail "update should give an actionable sudo retry command: $output"
if grep -Fq 'script should not run' <<<"$output"; then
  fail "update should not enter script(1) when sudo auth cannot read from a terminal"
fi

echo "PASS: ryoku-update refuses non-TTY sudo timeouts"
