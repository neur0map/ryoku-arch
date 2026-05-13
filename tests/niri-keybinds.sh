#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq "$pattern" "$file" || fail "$message"
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  ! grep -Eq "$pattern" "$file" || fail "$message"
}

for binds in config/niri/config.d/70-binds.kdl shell/defaults/niri/config.d/70-binds.kdl; do
  assert_contains "$binds" 'Mod\+Z[[:space:]]+\{[[:space:]]*focus-column-left;' \
    "$binds should bind Mod+Z to focus the column left"
  assert_contains "$binds" 'Mod\+X[[:space:]]+\{[[:space:]]*focus-column-right;' \
    "$binds should bind Mod+X to focus the column right"
  assert_contains "$binds" 'Mod\+Left[[:space:]]+\{[[:space:]]*focus-column-left;' \
    "$binds should keep the arrow-key left focus bind"
  assert_contains "$binds" 'Mod\+Right[[:space:]]+\{[[:space:]]*focus-column-right;' \
    "$binds should keep the arrow-key right focus bind"
  assert_contains "$binds" 'Mod\+Slash[[:space:]]+\{[[:space:]]*spawn "ryoku-shell" "cheatsheet" "toggle";' \
    "$binds should keep the Mod+/ cheatsheet bind"
  assert_contains "$binds" 'Mod\+S[[:space:]]+\{[[:space:]]*spawn "ryoku-shell" "toolsMode" "toggle";' \
    "$binds should keep the Mod+S toolkit bind"
done

for doc in docs/keybindings.md shell/docs/KEYBINDS.md; do
  assert_contains "$doc" 'Mod\+Z' "$doc should document Mod+Z focus left"
  assert_contains "$doc" 'Mod\+X' "$doc should document Mod+X focus right"
  assert_contains "$doc" 'Mod\+Left' "$doc should still document arrow focus"
  assert_contains "$doc" 'Mod\+Slash|Mod\+/' "$doc should still document the cheatsheet bind"
  assert_contains "$doc" 'Mod\+S' "$doc should still document the toolkit bind"
done

assert_not_contains shell/modules/tilingOverlay/TilingOverlay.qml 'Mod\+X cycle' \
  "tiling overlay should not claim Mod+X cycles layouts"

generated_doc="$(mktemp)"
trap 'rm -f "$generated_doc"' EXIT

bin/ryoku-dev-generate-keybindings-docs --stdout >"$generated_doc"

if ! cmp -s docs/keybindings.md "$generated_doc"; then
  diff -u docs/keybindings.md "$generated_doc" >&2 || true
  fail "docs/keybindings.md is stale. run bin/ryoku-dev-generate-keybindings-docs"
fi

python3 shell/scripts/parse_niri_keybinds.py config/niri/config.d/70-binds.kdl |
  jq -e '
    any(.children[].children[].keybinds[]; (.combo == "Mod+Z" and .comment == "Focus left")) and
    any(.children[].children[].keybinds[]; (.combo == "Mod+X" and .comment == "Focus right")) and
    any(.children[].children[].keybinds[]; (.combo == "Mod+Slash" and .comment == "Cheatsheet")) and
    any(.children[].children[].keybinds[]; (.combo == "Mod+S" and .comment == "Toolkit pill"))
  ' >/dev/null || fail "cheatsheet parser should expose Mod+Z, Mod+X, and Mod+Slash"

echo "OK: Niri keybind defaults"
