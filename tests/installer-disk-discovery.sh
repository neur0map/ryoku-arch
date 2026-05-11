#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
CONFIGURATOR="$ROOT_DIR/iso/configs/airootfs/root/configurator"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local pattern="$1"
  local message="$2"

  grep -Eq -- "$pattern" "$CONFIGURATOR" || fail "$message"
}

line_number() {
  local pattern="$1"

  grep -nE -- "$pattern" "$CONFIGURATOR" | head -n1 | cut -d: -f1
}

assert_order() {
  local first_pattern="$1"
  local second_pattern="$2"
  local message="$3"
  local first second

  first=$(line_number "$first_pattern")
  second=$(line_number "$second_pattern")

  [[ -n $first && -n $second ]] || fail "$message"
  (( first < second )) || fail "$message"
}

assert_contains 'probe_storage_modules\(\)' \
  "installer should probe storage modules before listing disks"
assert_contains 'vmd' \
  "installer should try Intel VMD storage support"
assert_contains 'nvme' \
  "installer should try NVMe storage support"
assert_contains 'ahci' \
  "installer should try SATA AHCI storage support"
assert_contains 'No installable disks detected' \
  "installer should explain an empty disk list instead of opening a blank picker"
assert_order 'probe_storage_modules' 'gum choose --header "Select install disk"' \
  "storage probing and empty-list handling should happen before the disk picker"

echo "PASS: installer disk discovery contract"
