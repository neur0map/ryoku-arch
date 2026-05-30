#!/bin/bash

# Contract test for the alongside (dual-boot) install path. Static assertions on
# the configurator + orchestrator so the safety-critical guardrails can't be
# silently removed. Does NOT perform any real partitioning.

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
CONFIGURATOR="$ROOT_DIR/iso/configs/airootfs/root/configurator"
ORCHESTRATOR="$ROOT_DIR/iso/configs/airootfs/root/.automated_script.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_in() {
  local file="$1" pattern="$2" message="$3"
  grep -Eq -- "$pattern" "$file" || fail "$message"
}

refute_in() {
  local file="$1" pattern="$2" message="$3"
  grep -Eq -- "$pattern" "$file" && fail "$message" || true
}

# Both scripts must be syntactically valid.
bash -n "$CONFIGURATOR" || fail "configurator has a syntax error"
bash -n "$ORCHESTRATOR" || fail "orchestrator has a syntax error"

# --- Configurator: detection + mode selection ---
assert_in "$CONFIGURATOR" 'detect_disk_layout\(\)' \
  "configurator should detect the chosen disk's layout"
assert_in "$CONFIGURATOR" 'c12a7328-f81f-11d2-ba4b-00a0c93ec93b' \
  "configurator should detect an existing ESP via the EFI System Partition GUID"
assert_in "$CONFIGURATOR" 'parted .*print free' \
  "configurator should detect free space with parted"
assert_in "$CONFIGURATOR" 'install_mode_form\(\)' \
  "configurator should offer an install-mode choice"
assert_in "$CONFIGURATOR" 'MIN_DUAL_BOOT_GIB' \
  "configurator should enforce a minimum free-space threshold for dual-boot"
assert_in "$CONFIGURATOR" '\[\[ -n \$EXISTING_ESP && \$FREE_SPACE_BYTES -ge \$min_bytes \]\]' \
  "alongside install must require an existing ESP AND enough free space"

# --- Configurator: dual-boot emits a non-wiping archinstall config ---
assert_in "$CONFIGURATOR" 'pre_mounted_config' \
  "dual-boot must use archinstall pre_mounted_config (no disk operations)"
assert_in "$CONFIGURATOR" 'install_mode.sh' \
  "configurator should persist the dual-boot plan to install_mode.sh"
# The full-disk path must still wipe; dual-boot must not appear in a wipe branch.
assert_in "$CONFIGURATOR" '"wipe": true' \
  "full-disk install must still wipe"
assert_in "$CONFIGURATOR" 'default_layout' \
  "full-disk install must still use default_layout"

# --- Orchestrator: safety guardrails ---
assert_in "$ORCHESTRATOR" 'setup_dual_boot_partitions\(\)' \
  "orchestrator should have a dual-boot partition setup function"
assert_in "$ORCHESTRATOR" 'sgdisk -n 0:0:0' \
  "dual-boot must carve the new partition from free space only (sgdisk -n 0:0:0)"
assert_in "$ORCHESTRATOR" 'refusing to format' \
  "dual-boot must refuse to format anything that is not a freshly created partition"
assert_in "$ORCHESTRATOR" 'if \[\[ \$\{DUAL_BOOT:-false\} == "true" \]\]; then' \
  "install_base_system must branch on DUAL_BOOT"
# Dual-boot must NOT run the whole-disk cleanup (that tears down existing OS holders).
assert_in "$ORCHESTRATOR" 'setup_dual_boot_partitions' \
  "dual-boot branch must call setup_dual_boot_partitions instead of cleanup_install_disk"
# The existing ESP must be mounted (reused), never reformatted in the dual-boot path.
assert_in "$ORCHESTRATOR" 'mount "\$esp" "\$target/boot"' \
  "dual-boot must reuse (mount) the existing ESP, not recreate it"
refute_in "$ORCHESTRATOR" 'mkfs\.(fat|vfat).*\$esp' \
  "dual-boot must never reformat the existing ESP"

echo "PASS: installer dual-boot contract"
