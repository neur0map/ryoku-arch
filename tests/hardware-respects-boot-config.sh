#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# Every hardware script that writes to /etc (boot/system config) must gate that
# write behind ryoku_boot_config_enabled, so a standalone shell install
# (RYOKU_BOOT_CONFIG=0) installs driver packages without rewriting the host's
# boot path.
scripts=(
  nvidia.sh
  gpu-render-primary.sh
  fix-fkeys.sh
  usb-autosuspend.sh
  fix-surface-keyboard.sh
  fix-tuxedo-backlight.sh
  apple/fix-spi-keyboard.sh
  apple/fix-suspend-nvme.sh
  apple/fix-t2.sh
  asus/fix-asus-ptl-b9406-display.sh
  asus/fix-asus-ptl-b9406-touchpad.sh
  asus/fix-asus-ptl-display-backlight.sh
  asus/fix-z13-touchpad.sh
  intel/fix-wifi7-eht.sh
  intel/ptl-kernel.sh
  dell/fix-xps-haptic-touchpad.sh
  lenovo/fix-yoga-pro7-bass-speakers.sh
)

for s in "${scripts[@]}"; do
  f="$ROOT_DIR/install/config/hardware/$s"
  [[ -f $f ]] || fail "missing install/config/hardware/$s"
  grep -q 'ryoku_boot_config_enabled' "$f" \
    || fail "$s must gate its /etc writes behind ryoku_boot_config_enabled"
  bash -n "$f" || fail "$s has a bash syntax error after guarding"
done

printf 'PASS: tests/hardware-respects-boot-config.sh\n'
