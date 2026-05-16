#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file() {
  local path=$1
  [[ -f $ROOT_DIR/$path ]] || fail "missing expected file: $path"
}

assert_absent() {
  local path=$1
  [[ ! -e $ROOT_DIR/$path ]] || fail "legacy channel file should not exist: $path"
}

assert_contains() {
  local path=$1 pattern=$2 message=$3
  rg -q -- "$pattern" "$ROOT_DIR/$path" || fail "$message"
}

assert_not_contains() {
  local path=$1 pattern=$2 message=$3
  if rg -q -- "$pattern" "$ROOT_DIR/$path"; then
    fail "$message"
  fi
}

assert_file default/pacman/pacman-main.conf
assert_file default/pacman/mirrorlist-main
assert_file iso/configs/pacman-online-main.conf

for path in \
  default/pacman/pacman-stable.conf \
  default/pacman/pacman-rc.conf \
  default/pacman/pacman-edge.conf \
  default/pacman/mirrorlist-stable \
  default/pacman/mirrorlist-rc \
  default/pacman/mirrorlist-edge \
  iso/configs/pacman-online-stable.conf \
  iso/configs/pacman-online-rc.conf \
  iso/configs/pacman-online-edge.conf; do
  assert_absent "$path"
done

active_files=(
  bin/ryoku-channel-set
  bin/ryoku-channel-current
  bin/ryoku-refresh-pacman
  bin/ryoku-branch-set
  bin/ryoku-update-branch
  bin/ryoku-reinstall-pkgs
  iso/bin/ryoku-iso-make
  iso/bin/ryoku-iso-release
  iso/bin/ryoku-iso-manifest
  iso/builder/build-iso.sh
  iso/configs/airootfs/root/.automated_script.sh
  install/preflight/pacman.sh
  install/post-install/pacman.sh
  boot.sh
)

for path in "${active_files[@]}"; do
  assert_contains "$path" 'main' "$path should reference the main channel"
  assert_not_contains "$path" 'RYOKU_MIRROR|ryoku_mirror' "$path should not use legacy mirror channel variables"
  assert_not_contains "$path" 'pacman-(stable|rc|edge)|mirrorlist-(stable|rc|edge)|pacman-online-(stable|rc|edge)' \
    "$path should not reference legacy pacman channel files"
  assert_not_contains "$path" 'stable-mirror|rc-mirror|edge-mirror' "$path should not reference legacy mirror names"
  assert_not_contains "$path" '--(rc|dev)([^A-Za-z0-9_-]|$)' "$path should not expose legacy release channel flags"
done

assert_contains .github/workflows/build-iso.yml 'CHANNEL: main' \
  "workflow should build the installer from the main channel"
assert_contains .github/workflows/build-iso.yml 'PUBLIC_CHANNEL: stable' \
  "workflow should publish ISO artifacts under the stable public R2 prefix"
assert_not_contains .github/workflows/build-iso.yml 'github\.event\.inputs\.channel' \
  "workflow should not expose a channel selector"
assert_not_contains .github/workflows/build-iso.yml 'ryoku/(stable|rc|edge)|ryoku-iso/(stable|rc|edge)' \
  "workflow should not upload to legacy channel paths"
assert_contains migrations/1778859665.sh 'printf .%s\\n. "main" > "\$STATE_FILE"' \
  "migration should rewrite legacy channel state to main"

echo "PASS: tests/channel-main-only.sh"
