#!/usr/bin/env bash
# shellcheck shell=bash
# Install the generation-correct GPU drivers in the target. The per-vendor scripts
# in system/hardware/drivers self-gate on the detected GPU (so running all of them
# is safe), are idempotent, and call pacman directly as root inside the chroot.
# Runs in the configure stage, after the base system and before the initramfs is
# built, so kernel modules (for example nvidia-dkms) are present for mkinitcpio.

ryoku_drivers() {
	log "installing GPU drivers for the detected hardware"
	local dir="$RYOKU_REPO/system/hardware/drivers" vendor name
	for vendor in amd intel nvidia vulkan; do
		[[ -f "$dir/$vendor.sh" ]] || {
			log "skip: $vendor.sh not present"
			continue
		}
		name="ryoku-driver-$vendor.sh"
		run cp "$dir/$vendor.sh" "/mnt/root/$name"
		run arch-chroot /mnt env RYOKU_DRYRUN="${RYOKU_DRYRUN:-}" bash "/root/$name"
		run rm -f "/mnt/root/$name"
	done
}
