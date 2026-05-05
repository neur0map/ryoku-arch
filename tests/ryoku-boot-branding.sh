#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

assert_file() {
  local path="$1"

  [[ -f $path ]] || fail "$path should exist"
}

assert_executable() {
  local path="$1"

  assert_file "$path"
  [[ -x $path ]] || fail "$path should be executable"
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

assert_file default/limine/default.conf
assert_file default/limine/limine.conf
assert_executable bin/ryoku-refresh-limine

bash -n bin/ryoku-refresh-limine || fail "ryoku-refresh-limine has a syntax error"

assert_contains default/limine/default.conf '^TARGET_OS_NAME="Ryoku"$' \
  "default Limine OS name should be Ryoku"
assert_contains default/limine/default.conf '^CUSTOM_UKI_NAME="ryoku"$' \
  "default Limine UKI name should be ryoku"
assert_contains default/limine/limine.conf '^interface_branding: Ryoku Bootloader$' \
  "default Limine interface branding should be Ryoku"
assert_not_contains default/limine/limine.conf 'Omarchy|omarchy_linux' \
  "default Limine config should not contain Omarchy boot branding"

assert_contains bin/ryoku-refresh-limine 'default/limine/default\.conf' \
  "Limine refresh should rewrite /etc/default/limine from Ryoku defaults"
assert_contains bin/ryoku-refresh-limine 'TARGET_OS_NAME="Ryoku"' \
  "Limine refresh should enforce the Ryoku OS name"
assert_contains bin/ryoku-refresh-limine 'CUSTOM_UKI_NAME="ryoku"' \
  "Limine refresh should enforce the Ryoku UKI name"
assert_contains bin/ryoku-refresh-limine 'limine-mkinitcpio' \
  "Limine refresh should regenerate the UKI, not only the menu"
assert_contains bin/ryoku-refresh-limine 'omarchy_hooks\.conf' \
  "Limine refresh should repair legacy Omarchy mkinitcpio hook filenames"
assert_contains bin/ryoku-refresh-limine 'ryoku_hooks\.conf' \
  "Limine refresh should install Ryoku mkinitcpio hook filenames"
assert_contains bin/ryoku-refresh-limine 'omarchy_resume\.conf' \
  "Limine refresh should repair legacy Omarchy resume filenames"
assert_contains bin/ryoku-refresh-limine 'ryoku_resume\.conf' \
  "Limine refresh should install Ryoku resume filenames"
assert_contains bin/ryoku-refresh-limine 'ryoku_linux\.efi' \
  "Limine refresh should verify the Ryoku UKI exists"
assert_contains bin/ryoku-refresh-limine 'omarchy_linux\.efi' \
  "Limine refresh should remove the legacy Omarchy UKI after verification"
assert_contains bin/ryoku-refresh-limine 'grep -q.*Ryoku' \
  "Limine refresh should verify the generated menu has Ryoku entries"
assert_contains bin/ryoku-refresh-limine 'limine-snapper-sync' \
  "Limine refresh should resync snapshot boot entries"

limine_repair_migration="$(grep -l 'ryoku-refresh-limine' migrations/*.sh 2>/dev/null | sort | tail -1)"
[[ -n $limine_repair_migration ]] || \
  fail "at least one migration should repair stale live Limine boot branding"

pass "Ryoku boot branding contract"
