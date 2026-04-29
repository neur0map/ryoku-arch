#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$ROOT_DIR/install/helpers/limine.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_fallback_adds_quiet_splash_without_duplication() {
  local temp_dir limine_config

  temp_dir=$(mktemp -d)
  limine_config="$temp_dir/limine.conf"

  cat >"$limine_config" <<'EOF'
timeout: 5

/Arch Linux (linux)
    protocol: linux
    path: boot():/vmlinuz-linux
    cmdline: cryptdevice=UUID=abc root=/dev/mapper/root rw
    module_path: boot():/initramfs-linux.img

/Arch Linux (fallback)
    protocol: linux
    path: boot():/vmlinuz-linux
    cmdline: cryptdevice=UUID=abc root=/dev/mapper/root rw quiet
    module_path: boot():/initramfs-linux-fallback.img
EOF

  ryoku_limine_ensure_cmdline_flags "$limine_config" quiet splash

  if (( $(grep -c '^    cmdline: cryptdevice=UUID=abc root=/dev/mapper/root rw quiet splash$' "$limine_config") != 2 )); then
    rm -rf "$temp_dir"
    fail "fallback should normalize every limine cmdline to quiet splash"
  fi

  if (( $(grep -c 'quiet quiet\|splash splash' "$limine_config") > 0 )); then
    rm -rf "$temp_dir"
    fail "fallback should not duplicate existing flags"
  fi

  rm -rf "$temp_dir"
}

assert_fallback_adds_quiet_splash_without_duplication

echo "PASS: limine splash fallback tests"
