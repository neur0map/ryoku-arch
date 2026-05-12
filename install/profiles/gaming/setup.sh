ryoku_profile_setup() {
  local gpu_lines

  command -v lspci >/dev/null 2>&1 || return 0
  gpu_lines="$(lspci | grep -iE '(VGA|3D|Display)' || true)"

  if [[ $gpu_lines =~ AMD|Radeon ]]; then
    ryoku_profile_install_pacman lib32-vulkan-radeon
  fi

  if [[ $gpu_lines =~ Intel ]]; then
    ryoku_profile_install_pacman lib32-vulkan-intel
  fi

  if [[ $gpu_lines =~ NVIDIA|Nvidia|nvidia ]]; then
    if pacman -Q nvidia-580xx-utils >/dev/null 2>&1; then
      ryoku_profile_install_aur lib32-nvidia-580xx-utils
    elif pacman -Q nvidia-utils >/dev/null 2>&1 || pacman -Q nvidia-open-dkms >/dev/null 2>&1; then
      ryoku_profile_install_pacman lib32-nvidia-utils
    fi
  fi
}
