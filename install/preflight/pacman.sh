if [[ -n ${RYOKU_ONLINE_INSTALL:-${OMARCHY_ONLINE_INSTALL:-}} ]]; then
  # Install build tools
  ryoku-pkg-add base-devel

  # Configure pacman. Channel selection is a simple stable/rc/edge knob;
  # RYOKU_MIRROR is the Ryoku-namespaced env var. OMARCHY_MIRROR remains
  # accepted as a transitional alias so pre-existing installer scripts and
  # ISO builds still work.
  channel="${RYOKU_MIRROR:-${OMARCHY_MIRROR:-stable}}"
  sudo cp -f "$RYOKU_PATH/default/pacman/pacman-$channel.conf" /etc/pacman.conf
  sudo cp -f "$RYOKU_PATH/default/pacman/mirrorlist-$channel" /etc/pacman.d/mirrorlist

  # Refresh all repos (no third-party keyring needed; archlinux-keyring
  # ships the only keys we consume now).
  sudo pacman -Syyuu --noconfirm
fi
