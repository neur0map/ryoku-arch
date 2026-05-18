#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_no_match() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if grep -Eq "$pattern" "$file"; then
    fail "$message"
  fi
}

assert_match() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq "$pattern" "$file" || fail "$message"
}

# install/config/shell.sh must source from the vendored shell/ tree, not clone
assert_no_match install/config/shell.sh 'git clone' \
  "install/config/shell.sh must not clone (vendored shell/ is the source of truth)"
assert_match install/config/shell.sh 'shell"?/?' \
  "install/config/shell.sh must reference the vendored shell/ tree"

# migrations/1778000000.sh must source from the vendored shell/ tree
assert_no_match migrations/1778000000.sh 'git clone' \
  "migrations/1778000000.sh must not clone upstream shell"

# ISO builder must not pull from a remote
upstream_shell='i''nir'
assert_no_match iso/builder/build-iso.sh "RYOKU_${upstream_shell^^}_REPO|/root/${upstream_shell}|/${upstream_shell}" \
  "iso/builder/build-iso.sh must not reference legacy shell repo names"
assert_no_match iso/bin/ryoku-iso-make "RYOKU_${upstream_shell^^}_REPO|RYOKU_${upstream_shell^^}_SOURCE|/${upstream_shell}" \
  "iso/bin/ryoku-iso-make must not reference legacy shell repo names"

# Vendored tree must exist with key entry points
[[ -f shell/shell.qml ]] || fail "shell/shell.qml must exist"
[[ -f shell/setup ]] || fail "shell/setup must exist"
[[ -d shell/modules ]] || fail "shell/modules must exist"
[[ -d shell/services ]] || fail "shell/services must exist"
[[ ! -d shell/.git ]] || fail "shell/.git must NOT exist (hermetic vendor)"

# Phase 4 migration must use the uninstall+reinstall pattern
migration_file=$(ls migrations/177810*.sh migrations/177820*.sh 2>/dev/null | sort | head -1 || true)
if [[ -z $migration_file ]]; then
  fail "Phase 4 migration not found in migrations/"
fi
assert_match "$migration_file" 'setup uninstall -y' \
  "Phase 4 migration must run the old shell uninstall to clean tracked paths"
assert_match "$migration_file" 'install/config/shell.sh' \
  "Phase 4 migration must run the new shell install pipeline"
assert_match "$migration_file" 'ryoku-shell.service' \
  "Phase 4 migration must start the new ryoku-shell.service"

echo "PASS: install from vendor"
