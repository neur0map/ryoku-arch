#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq "$pattern" "$ROOT_DIR/$file" || fail "$message"
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if grep -Eq "$pattern" "$ROOT_DIR/$file"; then
    fail "$message"
  fi
}

assert_offline_chroot_skips_script() {
  local script="$1"
  local detector="$2"
  local detector_body="$3"
  local temp_dir="$4"

  local bin_dir="$temp_dir/bin"
  mkdir -p "$bin_dir"

  cat >"$bin_dir/$detector" <<EOF
#!/bin/bash
$detector_body
EOF

  cat >"$bin_dir/ryoku-pkg-add" <<'EOF'
#!/bin/bash
echo "ryoku-pkg-add should not run during offline chroot custom package guard: $*" >&2
exit 99
EOF

  chmod 755 "$bin_dir/$detector" "$bin_dir/ryoku-pkg-add"

  env -i \
    HOME="$temp_dir/home" \
    PATH="$bin_dir:/usr/bin" \
    RYOKU_CHROOT_INSTALL=1 \
    USER=ryoku \
    /bin/bash "$ROOT_DIR/$script" \
    >"$temp_dir/$(basename "$script").log" 2>&1 || {
      cat "$temp_dir/$(basename "$script").log" >&2
      fail "$script should skip unbundled custom packages during offline ISO install"
    }
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

assert_not_contains \
  "iso/configs/airootfs/root/configurator" \
  'kernel_choice="linux-t2"' \
  "ISO configurator must not select linux-t2 because Ryoku does not bundle that custom Omarchy kernel"

for boot_file in \
  "iso/configs/airootfs/etc/mkinitcpio.d/linux.preset" \
  "iso/configs/efiboot/loader/entries/01-archiso-x86_64-linux.conf" \
  "iso/configs/grub/grub.cfg" \
  "iso/configs/grub/loopback.cfg" \
  "iso/configs/syslinux/archiso_pxe-linux.cfg" \
  "iso/configs/syslinux/archiso_sys-linux.cfg"; do
  assert_not_contains \
    "$boot_file" \
    'linux-t2' \
    "$boot_file must use the stock linux live kernel bundled in the Ryoku ISO"
done

assert_offline_chroot_skips_script \
  "install/config/hardware/intel/ptl-kernel.sh" \
  "ryoku-hw-intel-ptl" \
  "exit 0" \
  "$tmp_dir/ptl"

assert_offline_chroot_skips_script \
  "install/config/hardware/apple/fix-t2.sh" \
  "lspci" \
  'printf "%s\n" "0000:00:1f.0 Bridge [106b:1801]"' \
  "$tmp_dir/t2"

assert_contains \
  "install/config/hardware/intel/ipu7-camera.sh" \
  'RYOKU_CHROOT_INSTALL' \
  "IPU7 camera setup should explicitly guard the offline chroot"

assert_contains \
  "install/config/hardware/intel/ipu7-camera.sh" \
  'ryoku-pkg-aur-add intel-ipu7-camera-bin' \
  "IPU7 camera setup should use the AUR helper outside the offline ISO chroot"

assert_not_contains \
  "install/config/hardware/intel/ipu7-camera.sh" \
  'ryoku-pkg-add intel-ipu7-camera-bin' \
  "IPU7 camera setup must not ask pacman for an AUR-only package during install"

echo "PASS: offline ISO skips unbundled custom hardware packages"
