#!/bin/bash
# Stage 6: pacstrap the minimum Arch base into /mnt.

stage_header 6 10 "Install Base System"

info "Installing the base Arch system to /mnt. This downloads ~350 MiB"
info "of packages and takes a few minutes."

# Read packages.list, ignore comments + blanks.
mapfile -t packages < <(
  grep -vE '^\s*(#|$)' /usr/local/share/ryoku-install/packages.list
)

if (( ${#packages[@]} == 0 )); then
  abort "packages.list is empty or unreadable."
fi

info "Pacstrap will install ${#packages[@]} packages."

# Run pacstrap. -K initializes a fresh keyring inside /mnt; without it,
# pacman in the chroot would have no trusted keys.
pacstrap -K /mnt "${packages[@]}"

# Generate fstab from the current /mnt mount state.
genfstab -U /mnt > /mnt/etc/fstab

# Sanity check: fstab must mention root and /efi.
if ! grep -q 'subvol=@' /mnt/etc/fstab || \
   ! grep -q '/efi' /mnt/etc/fstab; then
  abort "genfstab produced an incomplete /mnt/etc/fstab" \
        "Inspect /mnt/etc/fstab and rerun stage 6."
fi

success "Base system installed; fstab written."
