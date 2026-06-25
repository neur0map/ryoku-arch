#!/usr/bin/env bash
#
# nvidia.sh: install the right NVIDIA driver stack when an NVIDIA GPU is present.
#
# Turing and newer (RTX 20xx and up, GTX 16xx, datacenter A/H/L) carry GSP
# firmware and run the open kernel modules, so they get nvidia-open-dkms. Older
# cards (Maxwell, Pascal, Volta) have no GSP and need the proprietary nvidia-dkms.
# Both get nvidia-utils (userspace), libva-nvidia-driver (VA-API) and
# linux-headers (the DKMS modules build against them).
#
# Idempotent: already-installed packages are left alone. Gated: does nothing when
# no NVIDIA GPU is detected. Dry run: RYOKU_DRYRUN=1 (or --dry-run) prints the
# pacman command instead of running it.

set -euo pipefail

RYOKU_DRYRUN="${RYOKU_DRYRUN:-0}"
for arg in "$@"; do
  case "$arg" in
    --dry-run) RYOKU_DRYRUN=1 ;;
    -h | --help)
      echo "Usage: nvidia.sh [--dry-run]"
      echo "Install NVIDIA drivers (open for Turing+, proprietary otherwise) if an NVIDIA GPU is present."
      exit 0
      ;;
    *)
      echo "nvidia.sh: unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

run() {
  if [[ $RYOKU_DRYRUN == 1 ]]; then
    printf 'DRYRUN: %s\n' "$*"
    return 0
  fi
  "$@"
}

write_root() {
  local path=$1
  if [[ $RYOKU_DRYRUN == 1 ]]; then
    printf 'DRYRUN: write %s\n' "$path"
    cat >/dev/null
    return 0
  fi
  if (( EUID == 0 )); then cat >"$path"; else sudo tee "$path" >/dev/null; fi
}

PM=(pacman)
(( EUID == 0 )) || PM=(sudo pacman)

pkg_installed() { pacman -Qq "$1" >/dev/null 2>&1; }

install_pkgs() {
  local missing=() p
  for p in "$@"; do pkg_installed "$p" || missing+=("$p"); done
  if (( ${#missing[@]} == 0 )); then
    echo "nvidia.sh: already installed: $*"
    return 0
  fi
  echo "nvidia.sh: installing ${missing[*]}"
  run "${PM[@]}" -S --needed --noconfirm "${missing[@]}"
}

has_lspci() { command -v lspci >/dev/null 2>&1; }

has_nvidia() {
  if has_lspci && lspci 2>/dev/null | grep -qi 'nvidia'; then
    return 0
  fi
  grep -rqs '^DRIVER=nvidia$' /sys/class/drm/card*/device/uevent 2>/dev/null
}

# GSP firmware support (open modules): GTX 16xx, RTX 20xx-50xx, RTX Pro, Quadro
# RTX, and datacenter A/H/T/L series. Ported from ryoku-hw-nvidia-gsp.
nvidia_has_gsp() {
  has_lspci || return 0   # unknown model: assume modern (open) when lspci is absent
  lspci | grep -i 'nvidia' \
    | grep -qE "GTX 16[0-9]{2}|RTX [2-5][0-9]{3}|RTX PRO [0-9]{4}|Quadro RTX|RTX A[0-9]{4}|A[1-9][0-9]{2}|H[1-9][0-9]{2}|T4|L[0-9]+"
}

if ! has_nvidia; then
  echo "nvidia.sh: no NVIDIA GPU detected, nothing to do."
  exit 0
fi

pkgs=(nvidia-utils libva-nvidia-driver linux-headers)
if nvidia_has_gsp; then
  echo "nvidia.sh: GSP-capable NVIDIA GPU (Turing+), using the open kernel modules."
  pkgs=(nvidia-open-dkms "${pkgs[@]}")
else
  echo "nvidia.sh: pre-Turing NVIDIA GPU, using the proprietary kernel modules."
  pkgs=(nvidia-dkms "${pkgs[@]}")
fi

install_pkgs "${pkgs[@]}"

# Early KMS plus the boot-race fix. The DRM modeset is mandatory for a working
# NVIDIA Wayland session, and the modules must load from the initramfs (rebuilt
# by the bootloader step, which runs after this). nouveau is blacklisted so it
# cannot also bind the card: when both modules can claim the GPU they race at
# boot and the card is detected only on some boots (the wonky-detection bug).
# PreserveVideoMemoryAllocations keeps the session intact across suspend.
# Detection-gated, so it applies whenever an NVIDIA GPU is present.
echo "nvidia.sh: writing modeset, nouveau blacklist + initramfs module config"
write_root /etc/modprobe.d/nvidia.conf <<'EOF'
options nvidia_drm modeset=1 fbdev=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
blacklist nouveau
options nouveau modeset=0
EOF
write_root /etc/mkinitcpio.conf.d/nvidia.conf <<'EOF'
MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
EOF

# Suspend/resume: NVIDIA must save and restore VRAM across sleep or the session
# comes back corrupted. These units ship with nvidia-utils; enabling them is
# offline-safe (just symlinks), so it works in the install chroot. A missing unit
# is tolerated.
if command -v systemctl >/dev/null 2>&1; then
  echo "nvidia.sh: enabling NVIDIA suspend/resume services"
  run systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service || true
fi

# Keep the initramfs in step with the NVIDIA modules across driver-only updates:
# otherwise the old module stays baked into the image while userspace moves on,
# and the version mismatch stops the GPU from initialising. Rebuild through
# limine-mkinitcpio (the UKI path) when present, else plain mkinitcpio.
echo "nvidia.sh: installing initramfs-rebuild pacman hook"
run mkdir -p /etc/pacman.d/hooks
write_root /etc/pacman.d/hooks/ryoku-nvidia.hook <<'EOF'
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
Target=nvidia-open-dkms
Target=nvidia-dkms
Target=nvidia-utils

[Action]
Description=Rebuilding the initramfs for the updated NVIDIA modules...
Depends=mkinitcpio
When=PostTransaction
Exec=/bin/sh -c 'if command -v limine-mkinitcpio >/dev/null 2>&1; then limine-mkinitcpio; else mkinitcpio -P; fi'
EOF
