# shellcheck disable=SC1091
source "$RYOKU_PATH/lib/hypr-config.sh"
if lspci | grep -qi 'nvidia'; then
  # Persist NVIDIA env to whichever config Hyprland loads (hyprland.lua or .conf).
  hypr_entry="$(hypr_entrypoint)"
  set_hyprland_env() {
    hypr_set_env "$hypr_entry" "$1" "$2"
  }

  # Check which kernel is installed and set appropriate headers package
  KERNEL_HEADERS="$(pacman -Qqs '^linux(-zen|-lts|-hardened)?$' | head -1)-headers"

  if ryoku-hw-nvidia-gsp; then
    PACKAGES=(nvidia-open-dkms nvidia-utils lib32-nvidia-utils libva-nvidia-driver)
    GPU_ARCH="turing_plus"
  elif ryoku-hw-nvidia-without-gsp; then
    PACKAGES=(nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils)
    GPU_ARCH="maxwell_pascal_volta"
  fi
  # Bail if no supported GPU
  if [[ -z ${PACKAGES+x} ]]; then
    echo "No compatible driver for your NVIDIA GPU. See: https://wiki.archlinux.org/title/NVIDIA"
    exit 0
  fi

  ryoku-pkg-add "$KERNEL_HEADERS" "${PACKAGES[@]}"

  if ryoku_boot_config_enabled; then
    # Configure modprobe for early KMS
    sudo tee /etc/modprobe.d/nvidia.conf <<EOF >/dev/null
options nvidia_drm modeset=1
EOF

    # Configure mkinitcpio for early loading
    sudo tee /etc/mkinitcpio.conf.d/nvidia.conf <<EOF >/dev/null
MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
EOF
  fi

  # Add NVIDIA environment variables based on GPU architecture.
  if [[ $GPU_ARCH = "turing_plus" ]]; then
    # Turing+ (RTX 20xx, GTX 16xx, and newer) with GSP firmware support
    set_hyprland_env NVD_BACKEND direct
    set_hyprland_env LIBVA_DRIVER_NAME nvidia
    set_hyprland_env __GLX_VENDOR_LIBRARY_NAME nvidia
  elif [[ $GPU_ARCH = "maxwell_pascal_volta" ]]; then
    # Maxwell/Pascal/Volta (GTX 9xx/10xx, GT 10xx, Quadro P/M/GV, MX series, Titan X/Xp/V) lack GSP firmware
    set_hyprland_env NVD_BACKEND egl
    set_hyprland_env __GLX_VENDOR_LIBRARY_NAME nvidia
  fi
fi
