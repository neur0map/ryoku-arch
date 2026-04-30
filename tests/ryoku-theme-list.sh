#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: ryoku theme list"
}

script="bin/ryoku-theme-list"
[[ -x $script ]] || fail "ryoku-theme-list should be executable"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/ryoku/themes/alpha" \
  "$tmpdir/ryoku/themes/beta" \
  "$tmpdir/config/themes/beta" \
  "$tmpdir/config/themes/custom" \
  "$tmpdir/config/current"
: >"$tmpdir/ryoku/themes/alpha/preview.png"
: >"$tmpdir/ryoku/themes/beta/preview.png"
: >"$tmpdir/config/themes/beta/preview.png"
printf '%s\n' "beta" >"$tmpdir/config/current/theme.name"

RYOKU_PATH="$tmpdir/ryoku" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
  "$script" --jsonl \
  | jq -se --arg beta_preview "$tmpdir/config/themes/beta/preview.png" '
      length == 3
      and [.[].name] == ["alpha", "beta", "custom"]
      and (.[1].preview == $beta_preview)
      and (.[1].active == true)
      and (.[2].preview == "")
    ' >/dev/null \
  || fail "theme list should merge shipped/user themes, prefer user preview, and mark active"

if "$script" --bogus >/dev/null 2>"$tmpdir/error.log"; then
  fail "unknown args should fail"
fi
grep -q "Usage: ryoku-theme-list --jsonl" "$tmpdir/error.log" \
  || fail "unknown args should print usage"

pass
