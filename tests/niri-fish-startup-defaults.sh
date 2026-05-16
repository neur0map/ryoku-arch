#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_focus_ring_disabled() {
  local path="$1"
  local block

  block="$(sed -n '/^[[:space:]]*focus-ring[[:space:]]*{/,/^[[:space:]]*}/p' "$ROOT_DIR/$path")"

  [[ -n $block ]] || fail "$path should define a focus-ring block"
  grep -Eq '^[[:space:]]*off[[:space:]]*$' <<< "$block" \
    || fail "$path should disable the focus ring by default"

  if grep -Eq '^[[:space:]]*active-gradient|#F25623|#F56E0F' <<< "$block"; then
    fail "$path should not ship an orange focus-ring gradient"
  fi
}

assert_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  rg -n "$pattern" "$ROOT_DIR/$path" >/dev/null || fail "$message"
}

assert_focus_ring_disabled "config/niri/config.d/20-layout-and-overview.kdl"
assert_focus_ring_disabled "shell/defaults/niri/config.d/20-layout-and-overview.kdl"

assert_contains "shell/dots/.config/fish/config.fish" 'set -g fish_greeting' \
  "fish config should disable the default welcome greeting globally"
assert_contains "shell/dots/.config/fish/config.fish" 'RYOKU_FASTFETCH_SHOWN' \
  "fish config should only show the startup logo once per terminal environment"
assert_contains "shell/dots/.config/fish/config.fish" '^[[:space:]]*fastfetch[[:space:]]*$' \
  "fish config should show the Ryoku fastfetch logo on startup"
assert_contains "shell/dots/.config/fish/config.fish" 'set -gx RYOKU_EDITOR nvim' \
  "fish config should set Ryoku's default editor for terminal tools"
assert_contains "shell/dots/.config/fish/config.fish" 'set -gx EDITOR \$RYOKU_EDITOR' \
  "fish config should export EDITOR for Yazi and other terminal tools"

assert_contains "shell/sdata/lib/package-installers.sh" 'set -g fish_greeting' \
  "fallback fish config should disable the default welcome greeting globally"
assert_contains "shell/sdata/lib/package-installers.sh" 'RYOKU_FASTFETCH_SHOWN' \
  "fallback fish config should only show the startup logo once per terminal environment"
assert_contains "shell/sdata/lib/package-installers.sh" '^[[:space:]]*fastfetch[[:space:]]*$' \
  "fallback fish config should show the Ryoku fastfetch logo on startup"
assert_contains "shell/sdata/lib/package-installers.sh" 'set -gx RYOKU_EDITOR nvim' \
  "fallback fish config should set Ryoku's default editor for terminal tools"
assert_contains "shell/sdata/lib/package-installers.sh" 'set -gx EDITOR \$RYOKU_EDITOR' \
  "fallback fish config should export EDITOR for Yazi and other terminal tools"

if command -v fish >/dev/null 2>&1; then
  fish -n "$ROOT_DIR/shell/dots/.config/fish/config.fish"
fi

printf 'PASS: tests/niri-fish-startup-defaults.sh\n'
