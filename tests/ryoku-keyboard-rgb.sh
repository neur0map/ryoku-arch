#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_DIR="$(mktemp -d)"

trap 'rm -rf "$TEMP_DIR"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

mkdir -p "$TEMP_DIR/bin" "$TEMP_DIR/config/current/theme"

cat >"$TEMP_DIR/bin/asusctl" <<'ASUSCTL'
#!/bin/bash
printf '%s\n' "$*" >"$ASUSCTL_ARGS_FILE"
ASUSCTL
chmod +x "$TEMP_DIR/bin/asusctl"

printf '242,86,35\n' >"$TEMP_DIR/config/current/theme/keyboard.rgb"

ASUSCTL_ARGS_FILE="$TEMP_DIR/asusctl.args" \
  PATH="$TEMP_DIR/bin:$PATH" \
  RYOKU_PATH="$ROOT_DIR" \
  RYOKU_CONFIG_PATH="$TEMP_DIR/config" \
  "$ROOT_DIR/bin/ryoku-theme-set-keyboard-asus-rog"

expected='aura effect static -c f25623'
actual="$(cat "$TEMP_DIR/asusctl.args")"

[[ $actual == "$expected" ]] || fail "asusctl should receive '$expected', got '$actual'"

echo "PASS: ryoku keyboard rgb"
