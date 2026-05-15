if lspci | grep -qi 'nvidia'; then
  set_niri_environment() {
    local key="$1"
    local value="$2"
    local file="$HOME/.config/niri/config.d/40-environment.kdl"

    if grep -Eq "^[[:space:]]*$key[[:space:]]+\"" "$file"; then
      sed -i "s|^[[:space:]]*$key[[:space:]].*|    $key \"$value\"|" "$file"
    elif grep -q '^[[:space:]]*environment[[:space:]]*{' "$file"; then
      sed -i "/^[[:space:]]*environment[[:space:]]*{/a\\    $key \"$value\"" "$file"
    else
      {
        printf '\nenvironment {\n'
        printf '    %s "%s"\n' "$key" "$value"
        printf '}\n'
      } >>"$file"
    fi
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

  # Configure modprobe for early KMS
  sudo tee /etc/modprobe.d/nvidia.conf <<EOF >/dev/null
options nvidia_drm modeset=1
EOF

  # Configure mkinitcpio for early loading
  sudo tee /etc/mkinitcpio.conf.d/nvidia.conf <<EOF >/dev/null
MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
EOF

  # Add NVIDIA environment variables based on GPU architecture
  mkdir -p "$HOME/.config/niri/config.d"
  touch "$HOME/.config/niri/config.d/40-environment.kdl"
  if [[ $GPU_ARCH = "turing_plus" ]]; then
    # Turing+ (RTX 20xx, GTX 16xx, and newer) with GSP firmware support
    set_niri_environment NVD_BACKEND direct
    set_niri_environment LIBVA_DRIVER_NAME nvidia
    set_niri_environment __GLX_VENDOR_LIBRARY_NAME nvidia
  elif [[ $GPU_ARCH = "maxwell_pascal_volta" ]]; then
    # Maxwell/Pascal/Volta (GTX 9xx/10xx, GT 10xx, Quadro P/M/GV, MX series, Titan X/Xp/V) lack GSP firmware
    set_niri_environment NVD_BACKEND egl
    set_niri_environment __GLX_VENDOR_LIBRARY_NAME nvidia
  fi
fi
