#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq "$pattern" "$ROOT_DIR/$path" || fail "$message"
}

assert_contains config/kitty/kitty.conf '^shell fish$' \
  "kitty should start the Ryoku fish profile by default"
assert_contains config/fish/config.fish 'ryoku-fastfetch' \
  "fish default should use the Ryoku fastfetch wrapper"
assert_contains config/fish/config.fish 'RYOKU_PATH/bin' \
  "fish default should add the Ryoku command directory before running fastfetch"
if grep -Eq 'TERM" = "xterm-kitty"|KITTY_WINDOW_ID|RYOKU_FASTFETCH_SHOWN_FOR' "$ROOT_DIR/config/fish/config.fish"; then
  fail "fish default should run fastfetch for every interactive terminal startup, not only Kitty"
fi

if command -v fish >/dev/null 2>&1; then
  tmp_dir=$(mktemp -d)
  tmp_home="$tmp_dir/test-home"
  tmp_ryoku="$tmp_dir/ryoku"
  trap 'rm -rf "$tmp_dir"' EXIT
  mkdir -p "$tmp_home/.config/fish" "$tmp_ryoku/bin"
  cp "$ROOT_DIR/config/fish/config.fish" "$tmp_home/.config/fish/config.fish"
  printf '%s\n' '#!/bin/bash' 'echo ryoku-fastfetch-called' >"$tmp_ryoku/bin/ryoku-fastfetch"
  chmod +x "$tmp_ryoku/bin/ryoku-fastfetch"

  output=$(
    HOME="$tmp_home" \
    RYOKU_PATH="$tmp_ryoku" \
    TERM=xterm-256color \
    PATH=/usr/bin \
      fish -ic true
  )

  [[ $output == *"ryoku-fastfetch-called"* ]] || \
    fail "fish default should invoke ryoku-fastfetch when an interactive terminal opens"
fi

echo "PASS: terminal opens with Ryoku fastfetch defaults"
