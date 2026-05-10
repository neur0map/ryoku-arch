#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
CONFIGURATOR="$ROOT_DIR/iso/configs/airootfs/root/configurator"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq -- "$pattern" "$file" || fail "$message"
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if grep -Eq -- "$pattern" "$file"; then
    fail "$message"
  fi
}

mapfile -t keymaps < <(
  awk '
    /keyboards=\$'\''/ { in_list = 1; sub(/^.*keyboards=\$'\''/, ""); }
    in_list {
      line = $0
      if (line ~ /'\''$/) {
        sub(/'\''$/, "", line)
        done = 1
      }
      if (line != "") {
        split(line, fields, "|")
        print fields[2]
      }
      if (done) exit
    }
  ' "$CONFIGURATOR"
)

[[ ${#keymaps[@]} -gt 0 ]] || fail "installer keymap list should not be empty"

if [[ -d /usr/share/kbd/keymaps ]]; then
  for keymap in "${keymaps[@]}"; do
    find /usr/share/kbd/keymaps \
      \( -name "$keymap.map" -o -name "$keymap.map.gz" \) \
      -print -quit | grep -q . || fail "installer keymap '$keymap' is not available to loadkeys"
  done
fi

assert_contains "$CONFIGURATOR" 'loadkeys "\$keyboard".*\|\| abort' \
  "configurator should abort if selected keymap cannot be applied before password entry"

assert_not_contains "$CONFIGURATOR" 'loadkeys "\$keyboard"[[:space:]]+2>/dev/null$' \
  "configurator should not silently ignore loadkeys failures before password entry"

echo "PASS: installer keymap validation"
