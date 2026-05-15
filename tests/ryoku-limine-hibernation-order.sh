#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"

  [[ -f $path ]] || fail "$path should exist"
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

line_number() {
  local file="$1"
  local pattern="$2"

  grep -nE -- "$pattern" "$file" | head -n1 | cut -d: -f1
}

assert_order() {
  local file="$1"
  local first_pattern="$2"
  local second_pattern="$3"
  local message="$4"
  local first second

  first=$(line_number "$file" "$first_pattern")
  second=$(line_number "$file" "$second_pattern")

  [[ -n $first && -n $second ]] || fail "$message"
  (( first < second )) || fail "$message"
}

assert_file install/login/hibernation.sh
assert_contains install/login/hibernation.sh 'ryoku-hibernation-setup --force --no-rebuild' \
  "install-time hibernation should skip its own rebuild and let Limine setup rebuild once"
assert_order install/login/all.sh 'login/hibernation\.sh' 'login/limine-snapper\.sh' \
  "hibernation setup should run before limine-snapper"
assert_not_contains install/post-install/all.sh 'post-install/hibernation\.sh' \
  "post-install should not rebuild hibernation after limine setup"

assert_contains bin/ryoku-hibernation-setup 'NO_REBUILD=false' \
  "hibernation setup should parse a --no-rebuild mode"
assert_contains bin/ryoku-hibernation-setup '--no-rebuild\) NO_REBUILD=true' \
  "hibernation setup should accept --no-rebuild"
assert_contains bin/ryoku-hibernation-setup 'if ! \$NO_REBUILD' \
  "hibernation setup should guard rebuild work behind NO_REBUILD"
assert_not_contains bin/ryoku-hibernation-setup '^[[:space:]]*sudo limine-update' \
  "hibernation setup should not call limine-update directly"

assert_contains install/login/limine-snapper.sh 'limine-mkinitcpio' \
  "limine-snapper should use limine-mkinitcpio when available"
assert_contains install/login/limine-snapper.sh "if ! grep -q '\\^/\\+Ryoku' /boot/limine\\.conf" \
  "limine-snapper should only fall back to limine-update when entries are missing"

bash -n bin/ryoku-hibernation-setup install/login/hibernation.sh install/login/limine-snapper.sh

echo "PASS: Ryoku hibernation and Limine install ordering"
