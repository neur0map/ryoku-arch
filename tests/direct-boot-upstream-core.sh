#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

run_direct_boot_case() {
  local tmp_dir="$1"
  local efibootmgr_output="$2"

  mkdir -p "$tmp_dir/bin" "$tmp_dir/sys/firmware/efi" "$tmp_dir/dmi" "$tmp_dir/EFI/Linux"
  printf 'Framework\n' >"$tmp_dir/dmi/bios_vendor"
  : >"$tmp_dir/events"

  cat >"$tmp_dir/bin/efibootmgr" <<'EOF'
#!/bin/bash
printf '%s' "$RYOKU_TEST_EFIBOOTMGR_OUTPUT"
EOF

  cat >"$tmp_dir/bin/gum" <<'EOF'
#!/bin/bash
printf 'gum:%s\n' "$*" >>"$RYOKU_TEST_EVENTS"
[[ ${1:-} == "confirm" ]]
EOF

  cat >"$tmp_dir/bin/findmnt" <<'EOF'
#!/bin/bash
printf '/dev/nvme0n1p1\n'
EOF

  cat >"$tmp_dir/bin/sudo" <<'EOF'
#!/bin/bash
printf 'sudo:%s\n' "$*" >>"$RYOKU_TEST_EVENTS"
EOF

  chmod 755 "$tmp_dir/bin"/*

  RYOKU_TEST_EVENTS="$tmp_dir/events" \
  RYOKU_TEST_EFIBOOTMGR_OUTPUT="$efibootmgr_output" \
  RYOKU_EFI_FIRMWARE_DIR="$tmp_dir/sys/firmware/efi" \
  RYOKU_BIOS_VENDOR_FILE="$tmp_dir/dmi/bios_vendor" \
  RYOKU_EFI_LINUX_DIR="$tmp_dir/EFI/Linux" \
  RYOKU_BOOT_MOUNT_PATH="$tmp_dir/boot" \
  PATH="$tmp_dir/bin:$PATH" \
    "$ROOT_DIR/bin/ryoku-config-direct-boot" >"$tmp_dir/output" 2>&1
}

create_tmp=$(mktemp -d)
mkdir -p "$create_tmp/EFI/Linux"
touch "$create_tmp/EFI/Linux/ryoku_linux.efi"
run_direct_boot_case "$create_tmp" $'Boot0001* Linux Boot Manager\n'

grep -q -- '--create' "$create_tmp/events" || \
  fail "direct boot should create a Ryoku EFI entry when one is missing"
grep -q -- '--disk /dev/nvme0n1' "$create_tmp/events" || \
  fail "direct boot should derive the parent disk for NVMe boot partitions"
grep -q -- '--part 1' "$create_tmp/events" || \
  fail "direct boot should derive the boot partition number"
grep -q -- '--label Ryoku' "$create_tmp/events" || \
  fail "direct boot should create a Ryoku-labelled EFI entry"
grep -Fq -- '--loader \EFI\Linux\ryoku_linux.efi' "$create_tmp/events" || \
  fail "direct boot should point at the Ryoku UKI"

remove_tmp=$(mktemp -d)
mkdir -p "$remove_tmp/EFI/Linux"
touch "$remove_tmp/EFI/Linux/ryoku_linux.efi"
run_direct_boot_case "$remove_tmp" $'Boot000A* Ryoku\n'

grep -qx 'sudo:efibootmgr --bootnum 000A --delete-bootnum' "$remove_tmp/events" || \
  fail "direct boot should remove an existing Ryoku EFI entry"
if grep -q -- '--create' "$remove_tmp/events"; then
  fail "direct boot should not create a duplicate entry when Ryoku already exists"
fi

missing_tmp=$(mktemp -d)
if run_direct_boot_case "$missing_tmp" $'Boot0001* Linux Boot Manager\n'; then
  fail "direct boot should fail when no Ryoku UKI exists"
fi
grep -q 'No Ryoku UKI found' "$missing_tmp/output" || \
  fail "direct boot should explain missing Ryoku UKI"

grep -q 'ryoku\*\.efi' bin/ryoku-config-direct-boot || \
  fail "direct boot should search for Ryoku UKIs"
if grep -q 'omarchy\*\.efi' bin/ryoku-config-direct-boot; then
  fail "direct boot should not search for Omarchy UKIs"
fi

bash -n bin/ryoku-config-direct-boot tests/direct-boot-upstream-core.sh

echo "PASS: direct boot upstream parity"
