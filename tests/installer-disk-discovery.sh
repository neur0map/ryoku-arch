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

assert_root_disk_self_parent_guard() {
  local tmpdir output

  tmpdir=$(mktemp -d)
  mkdir -p "$tmpdir/bin"

  cat >"$tmpdir/bin/readlink" <<'MOCK'
#!/bin/bash
if [[ ${1:-} == "-f" && -n ${2:-} ]]; then
  printf "%s\n" "$2"
  exit 0
fi
exec /usr/bin/readlink "$@"
MOCK

  cat >"$tmpdir/bin/lsblk" <<'MOCK'
#!/bin/bash
if [[ ${1:-} == "-no" && ${2:-} == "PKNAME" ]]; then
  case "${3:-}" in
    /dev/sda1|/dev/sda)
      printf "sda\n"
      ;;
  esac
  exit 0
fi

if [[ ${1:-} == "-dno" && ${2:-} == "TYPE" ]]; then
  [[ ${3:-} == "/dev/sda" ]] && printf "disk\n"
  exit 0
fi

printf "unexpected lsblk call:" >&2
printf " %q" "$@" >&2
printf "\n" >&2
exit 2
MOCK

  chmod +x "$tmpdir/bin/readlink" "$tmpdir/bin/lsblk"

  sed -n '/^get_root_disk() {/,/^}/p' "$CONFIGURATOR" >"$tmpdir/run.sh"
  printf 'get_root_disk /dev/sda1\n' >>"$tmpdir/run.sh"

  if ! output=$(PATH="$tmpdir/bin:$PATH" timeout 2s bash "$tmpdir/run.sh" 2>&1); then
    rm -rf "$tmpdir"
    fail "get_root_disk should not loop forever when lsblk reports a disk as its own parent"
  fi

  rm -rf "$tmpdir"
  [[ $output == "/dev/sda" ]] || fail "get_root_disk should resolve /dev/sda1 to /dev/sda, got: $output"
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
assert_root_disk_self_parent_guard

echo "PASS: installer disk discovery contract"
