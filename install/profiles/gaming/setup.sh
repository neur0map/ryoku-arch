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
    # Match the installed driver flavor and install the matching lib32
    # vulkan/userspace package. Order matters: the 580xx AUR package
    # conflicts with the official lib32-nvidia-utils, so handle the
    # legacy 580 driver first and pre-remove the conflicting official
    # package non-interactively. For everything else (current driver,
    # -open, -dkms, -open-dkms), the official lib32-nvidia-utils is
    # the right choice. As a fallback for fresh boxes with no NVIDIA
    # driver installed yet, install lib32-nvidia-utils so Steam isn't
    # broken the first time it launches.
    if pacman -Q nvidia-580xx-utils >/dev/null 2>&1; then
      if pacman -Q lib32-nvidia-utils >/dev/null 2>&1; then
        if (( EUID == 0 )); then
          pacman -Rdd --noconfirm lib32-nvidia-utils >/dev/null 2>&1 || true
        else
          sudo pacman -Rdd --noconfirm lib32-nvidia-utils >/dev/null 2>&1 || true
        fi
      fi
      ryoku_profile_install_aur lib32-nvidia-580xx-utils
    else
      # Includes pacman -Q nvidia-utils / nvidia-open-dkms / nvidia-dkms /
      # nvidia-open AND the no-driver-installed case.
      ryoku_profile_install_pacman lib32-nvidia-utils
    fi
  fi

  # Add the target user to the `gamemode` group so gamemoded actually
  # applies optimizations (CAP_SYS_NICE is gated to gamemode group
  # members by /usr/lib/sysusers.d/gamemode.conf in the gamemode pkg).
  if getent group gamemode >/dev/null 2>&1; then
    local target_user
    target_user="$(ryoku_profile_target_user)"
    if [[ -n $target_user && $target_user != "root" ]]; then
      if ! id -nG "$target_user" 2>/dev/null | tr ' ' '\n' | grep -qx gamemode; then
        if (( EUID == 0 )); then
          usermod -a -G gamemode "$target_user" || true
        else
          sudo usermod -a -G gamemode "$target_user" || true
        fi
        printf '[gaming-profile] Added %s to the gamemode group. Log out and back in for it to take effect.\n' "$target_user"
      fi
    fi
  fi
}
