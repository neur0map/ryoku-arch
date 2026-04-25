#!/bin/bash
# Stage 1: Pre-flight checks. Aborts the install if the live env can't
# host the kind of system Ryoku boot.sh expects.

stage_header 1 10 "Pre-flight"

info "Checking that the live environment can host a Ryoku install."

# UEFI mode required (limine + the spec assume UEFI).
if [[ ! -d /sys/firmware/efi ]]; then
  abort "UEFI mode required." "Reboot in UEFI mode and try again."
fi
info "✓ UEFI mode"

# Secure Boot must be off (limine cannot boot under Secure Boot without
# a signed binary; we do not ship one).
if bootctl status 2>/dev/null | grep -q 'Secure Boot: enabled'; then
  abort "Secure Boot must be disabled." \
        "Disable Secure Boot in your firmware setup, reboot, retry."
fi
info "✓ Secure Boot disabled"

# Network up. Test what boot.sh actually needs (HTTPS to GitHub) rather
# than ICMP, which is blocked under QEMU user-mode networking and on
# some corporate networks even when the network is otherwise fine.
if ! curl -fsSL --max-time 8 -o /dev/null https://github.com 2>/dev/null; then
  abort "Network is required." \
        "Use 'nmtui' to connect to Wi-Fi, or check your ethernet cable."
fi
info "✓ Network OK"

# Suitable disks: at least one block device of type 'disk' that is at
# least 20 GiB. Small enough to flag obvious mistakes (a tiny USB) but
# permissive for real laptops.
mapfile -t disks < <(
  lsblk -dn -b -o NAME,SIZE,TYPE \
    | awk '$3=="disk" && $2 >= 20*1024*1024*1024 { print $1 }'
)
if (( ${#disks[@]} == 0 )); then
  abort "No suitable target disks found." \
        "Install requires a disk of at least 20 GiB."
fi
info "✓ ${#disks[@]} candidate disk(s) detected"

success "Pre-flight: OK"

# Export for stage 2 (disk selection).
export RYOKU_CANDIDATE_DISKS="${disks[*]}"
