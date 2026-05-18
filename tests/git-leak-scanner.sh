#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SCANNER="$ROOT_DIR/bin/ryoku-dev-scan-leaks"

assert_rejects_file() {
  local temp_dir="$1"
  local name="$2"
  local content="$3"
  local file="$temp_dir/$name"

  printf '%s\n' "$content" >"$file"

  if "$SCANNER" --files "$file" >"$temp_dir/$name.out" 2>"$temp_dir/$name.err"; then
    echo "FAIL: scanner should reject $name" >&2
    cat "$temp_dir/$name.out" >&2
    cat "$temp_dir/$name.err" >&2
    return 1
  fi
}

assert_allows_file() {
  local temp_dir="$1"
  local name="$2"
  local content="$3"
  local file="$temp_dir/$name"

  printf '%s\n' "$content" >"$file"

  if ! "$SCANNER" --files "$file" >"$temp_dir/$name.out" 2>"$temp_dir/$name.err"; then
    echo "FAIL: scanner should allow $name" >&2
    cat "$temp_dir/$name.out" >&2
    cat "$temp_dir/$name.err" >&2
    return 1
  fi
}

main() {
  local temp_dir upstream_shell

  temp_dir="$(mktemp -d)"
  upstream_shell='i''nir'
  trap "rm -rf '$temp_dir'" EXIT

  assert_rejects_file "$temp_dir" "hardcoded-home.kdl" \
    "Mod+Space { spawn \"/home/carlos/.local/bin/${upstream_shell}\" \"overview\" \"toggle\"; }"
  assert_rejects_file "$temp_dir" "mac-home.conf" \
    'source = /Users/carlos/.config/ryoku/private.conf'
  assert_rejects_file "$temp_dir" "windows-home.txt" \
    'cache=C:\Users\carlos\AppData\Local\Ryoku'
  assert_rejects_file "$temp_dir" "runtime-uid.service" \
    'Environment=WAYLAND_DISPLAY=/run/user/1000/wayland-1'
  assert_rejects_file "$temp_dir" "machine-uki.txt" \
    '/boot/EFI/Linux/a639ef7cc2654160ad26279f5e849b21_linux.efi'

  assert_allows_file "$temp_dir" "portable-paths.sh" \
    "exec \"\$HOME/.local/bin/${upstream_shell}\" \"\$RYOKU_PATH/install/config/${upstream_shell}.sh\" ~/.config/niri/config.kdl"

  grep -Eq 'ryoku-dev-scan-leaks"?[[:space:]]+--staged' "$ROOT_DIR/.githooks/pre-commit" || {
    echo "FAIL: pre-commit should call ryoku-dev-scan-leaks --staged" >&2
    return 1
  }

  echo "PASS: git leak scanner"
}

main "$@"
