#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local path="$1"
  local needle="$2"

  grep -qF "$needle" "$ROOT_DIR/$path" || fail "$path should contain: $needle"
}

assert_not_contains() {
  local path="$1"
  local needle="$2"

  ! grep -qF "$needle" "$ROOT_DIR/$path" || fail "$path should not contain: $needle"
}

package_installers="shell/sdata/lib/package-installers.sh"
legacy_shell="i""nir"

assert_contains "$package_installers" 'grep -q "include=.*ryoku-shell-colors\.ini"'
assert_not_contains "$package_installers" "if ! grep -q \"include=.*${legacy_shell}-colors"

assert_contains "$package_installers" 'legacy_shell_config_dir=".config/i""nir"'
assert_contains "$package_installers" 'source.*ryoku-shell/bashrc'
assert_contains "$package_installers" 'source.*ryoku-shell/zshrc'
# shellcheck disable=SC2016
assert_contains "$package_installers" 's|~/${legacy_shell_config_dir}/bashrc|~/.config/ryoku-shell/bashrc|g'
# shellcheck disable=SC2016
assert_contains "$package_installers" 's|~/${legacy_shell_config_dir}/zshrc|~/.config/ryoku-shell/zshrc|g'
assert_not_contains "$package_installers" "source.*${legacy_shell}/bashrc"
assert_not_contains "$package_installers" "source.*${legacy_shell}/zshrc"

echo "PASS: shell package integrations migrate to Ryoku paths"
