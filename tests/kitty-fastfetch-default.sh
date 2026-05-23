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
assert_contains config/fish/config.fish 'TERM" = "xterm-kitty"' \
  "fish default should scope the startup fetch to Kitty"
assert_contains config/fish/config.fish 'KITTY_WINDOW_ID' \
  "fish default should key fastfetch to the current Kitty window"
assert_contains config/fish/config.fish 'RYOKU_FASTFETCH_SHOWN_FOR' \
  "fish default should avoid repeating fastfetch in the same Kitty shell"
assert_contains config/fish/config.fish 'ryoku-fastfetch' \
  "fish default should use the Ryoku fastfetch wrapper"

if command -v fish >/dev/null 2>&1; then
  tmp_dir=$(mktemp -d)
  tmp_home="$tmp_dir/test-home"
  trap 'rm -rf "$tmp_dir"' EXIT
  mkdir -p "$tmp_home/.config/fish" "$tmp_dir/bin"
  cp "$ROOT_DIR/config/fish/config.fish" "$tmp_home/.config/fish/config.fish"
  printf '%s\n' '#!/bin/bash' 'echo ryoku-fastfetch-called' >"$tmp_dir/bin/ryoku-fastfetch"
  chmod +x "$tmp_dir/bin/ryoku-fastfetch"

  output=$(
    HOME="$tmp_home" \
    TERM=xterm-kitty \
    KITTY_WINDOW_ID=42 \
    PATH="$tmp_dir/bin:$PATH" \
      fish -ic true
  )

  [[ $output == *"ryoku-fastfetch-called"* ]] || \
    fail "fish default should invoke ryoku-fastfetch when Kitty opens"
fi

echo "PASS: Kitty opens with Ryoku fastfetch defaults"
