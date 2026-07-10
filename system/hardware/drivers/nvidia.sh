#!/usr/bin/env bash
#
# nvidia.sh: pick + install the right NVIDIA stack if a card is there.
#
# Turing+ (GTX 16xx, RTX 20xx-up, datacenter A/H/L) ship GSP firmware and use
# the open kernel modules; older cards (Maxwell/Pascal/Volta) use the
# proprietary ones. On the stock `linux` kernel we install the PREBUILT module
# (nvidia-open / nvidia) so there is no DKMS build to fail on a fresh kernel; a
# custom kernel falls back to nvidia-open-dkms / nvidia-dkms + headers. Both add
# nvidia-utils + libva-nvidia-driver. The early-KMS mkinitcpio config is written
# only when the module actually landed, so a driver that cannot build never
# breaks the initramfs (the machine still boots on the iGPU).
#
# idempotent, gated on detection, dry-run via RYOKU_DRYRUN (or --dry-run).

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
  if (( EUID == 0 )); then cat >"$path"; else sudo -n tee "$path" >/dev/null; fi
}

PM=(pacman)
PRIV=()
if (( EUID != 0 )); then
  PM=(sudo -n pacman)
  PRIV=(sudo -n)
fi

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

# GSP-firmware cards (-> open modules): GTX 16xx, RTX 20xx-50xx, RTX Pro,
# Quadro RTX, datacenter A/H/T/L. ported from ryoku-hw-nvidia-gsp.
nvidia_has_gsp() {
  has_lspci || return 0   # no lspci -> assume modern (open). safe default.
  lspci | grep -i 'nvidia' \
    | grep -qE "GTX 16[0-9]{2}|RTX [2-5][0-9]{3}|RTX PRO [0-9]{4}|Quadro RTX|RTX A[0-9]{4}|A[1-9][0-9]{2}|H[1-9][0-9]{2}|T4|L[0-9]+"
}

if ! has_nvidia; then
  echo "nvidia.sh: no NVIDIA GPU detected, nothing to do."
  exit 0
fi

# an installed module package stays: CachyOS boxes ship kernel-matched
# prebuilt modules (linux-cachyos-nvidia-open) that provide NVIDIA-MODULE,
# and adding a -dkms package conflicts with it, aborting the transaction.
have_module_pkg() {
  pacman -Qq 2>/dev/null | grep -qE '^(nvidia(-open)?(-dkms|-lts)?|linux-.*-nvidia(-open)?)$'
}

# nvidia_module_present: is the nvidia kernel module actually available for an
# installed target kernel? checks each /usr/lib/modules/<ver> tree with
# modinfo -k (not the chroot's running host kernel). dry-run assumes present.
nvidia_module_present() {
  [[ $RYOKU_DRYRUN == 1 ]] && return 0
  local d kv
  for d in /usr/lib/modules/*/; do
    [[ -d $d ]] || continue
    kv=${d%/}; kv=${kv##*/}
    modinfo -k "$kv" nvidia >/dev/null 2>&1 && return 0
  done
  return 1
}

if have_module_pkg; then
  echo "nvidia.sh: an NVIDIA kernel module package is already installed, keeping it"
  install_pkgs nvidia-utils libva-nvidia-driver
else
  # enumerate the installed kernels via pkgbase (linux, linux-zen, ...).
  kernels=()
  for pb in /usr/lib/modules/*/pkgbase; do
    [[ -r $pb ]] || continue
    read -r kb <"$pb"
    kernels+=("$kb")
  done
  (( ${#kernels[@]} )) || kernels=(linux)
  mapfile -t kernels < <(printf '%s\n' "${kernels[@]}" | sort -u)

  # the stock `linux` kernel ships a PREBUILT nvidia module (nvidia-open /
  # nvidia) kept in step with it, so there is no DKMS build to fail on a fresh
  # kernel. any custom kernel (zen/lts/cachyos) needs DKMS + its headers.
  base=(nvidia-utils libva-nvidia-driver)
  if [[ ${#kernels[@]} -eq 1 && ${kernels[0]} == linux ]]; then
    if nvidia_has_gsp; then
      echo "nvidia.sh: Turing+ GPU on stock linux, using the prebuilt open module (nvidia-open)."
      pkgs=(nvidia-open "${base[@]}")
    else
      echo "nvidia.sh: pre-Turing GPU on stock linux, using the prebuilt proprietary module (nvidia)."
      pkgs=(nvidia "${base[@]}")
    fi
  else
    headers=()
    for kb in "${kernels[@]}"; do headers+=("${kb}-headers"); done
    if nvidia_has_gsp; then
      echo "nvidia.sh: Turing+ GPU, custom kernel(s), using nvidia-open-dkms."
      pkgs=(nvidia-open-dkms "${base[@]}" "${headers[@]}")
    else
      echo "nvidia.sh: pre-Turing GPU, custom kernel(s), using nvidia-dkms."
      pkgs=(nvidia-dkms "${base[@]}" "${headers[@]}")
    fi
  fi
  install_pkgs "${pkgs[@]}" || echo "nvidia.sh: WARNING: NVIDIA driver install failed (a pre-Turing card may need an AUR legacy driver such as nvidia-580xx-dkms; a Turing+ card needs a matching kernel/driver). The desktop will run on the integrated GPU; install a working driver and run 'mkinitcpio -P' to enable it."
fi

# early KMS + the boot-race fix. DRM modeset is mandatory for a working
# NVIDIA Wayland session, and the modules have to come from the initramfs
# (rebuilt by the bootloader step after this). nouveau gets denylisted so
# it can't also bind the card: with both modules eligible they race at
# boot, and the card only shows up on some boots (the wonky-detection bug).
# PreserveVideoMemoryAllocations = session survives suspend.
# detection-gated, applied whenever an NVIDIA GPU is present.
echo "nvidia.sh: writing modeset + nouveau blacklist"
write_root /etc/modprobe.d/nvidia.conf <<'EOF'
options nvidia_drm modeset=1 fbdev=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
blacklist nouveau
options nouveau modeset=0
EOF
# early KMS (nvidia in the initramfs) ONLY when the module actually landed. a
# forced MODULES=(nvidia...) with a missing module makes mkinitcpio ERROR and
# ship a broken initramfs -- the classic hybrid-laptop install break. without
# the module we skip it and warn; the iGPU still drives the display.
if nvidia_module_present; then
  echo "nvidia.sh: nvidia module present, writing initramfs early-KMS config"
  write_root /etc/mkinitcpio.conf.d/nvidia.conf <<'EOF'
MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
EOF
else
  echo "nvidia.sh: WARNING: nvidia kernel module not found for the installed kernel(s); skipping the mkinitcpio MODULES drop-in so the initramfs still builds. Boot runs on the integrated GPU; install a matching nvidia driver/kernel and run 'mkinitcpio -P' to enable it."
  run "${PRIV[@]}" rm -f /etc/mkinitcpio.conf.d/nvidia.conf
fi

# suspend/resume: NVIDIA has to save + restore VRAM across sleep or the
# session comes back corrupted. units ship in nvidia-utils; enabling them
# is offline-safe (just symlinks), so this works in the install chroot too.
# missing unit tolerated.
if command -v systemctl >/dev/null 2>&1; then
  echo "nvidia.sh: enabling NVIDIA suspend/resume services"
  run "${PRIV[@]}" systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service || true
fi

# keep the initramfs in step with the NVIDIA modules on driver-only updates,
# else the old module stays baked into the image while userspace moves on,
# version mismatch, GPU won't init. rebuild via limine-mkinitcpio (the UKI
# path) when present, else plain mkinitcpio.
echo "nvidia.sh: installing initramfs-rebuild pacman hook"
run "${PRIV[@]}" mkdir -p /etc/pacman.d/hooks
# prebuilt module packages (linux-cachyos-nvidia-open etc.) join the trigger
# list; the Exec probes for the generator so dracut boxes work too, and no
# Depends=mkinitcpio, which would make pacman skip the hook there.
{
  cat <<'EOF'
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
Target=nvidia-open-dkms
Target=nvidia-dkms
Target=nvidia-utils
EOF
  pacman -Qq 2>/dev/null | grep -E '^linux-.*-nvidia(-open)?$' | sed 's/^/Target=/'
  cat <<'EOF'

[Action]
Description=Rebuilding the initramfs for the updated NVIDIA modules...
When=PostTransaction
Exec=/bin/sh -c 'if command -v limine-mkinitcpio >/dev/null 2>&1; then limine-mkinitcpio; elif command -v mkinitcpio >/dev/null 2>&1; then mkinitcpio -P; elif command -v dracut-rebuild >/dev/null 2>&1; then dracut-rebuild; elif command -v dracut >/dev/null 2>&1; then dracut --regenerate-all --force; fi'
EOF
} | write_root /etc/pacman.d/hooks/ryoku-nvidia.hook
