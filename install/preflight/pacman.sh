if [[ -n ${RYOKU_ONLINE_INSTALL:-} ]]; then
  # Install build tools
  ryoku-pkg-add base-devel

  # Configure pacman. Channel selection (stable / rc / edge) only picks
  # which committed mirrorlist snapshot and pacman.conf to copy into
  # place. All three share the same upstream Arch repos today; the names
  # survive as scaffolding for future differentiation.
  channel="${RYOKU_MIRROR:-stable}"
  sudo cp -f "$RYOKU_PATH/default/pacman/pacman-$channel.conf" /etc/pacman.conf
  sudo cp -f "$RYOKU_PATH/default/pacman/mirrorlist-$channel" /etc/pacman.d/mirrorlist

  # Refresh all repos (archlinux-keyring ships the only keys we consume).
  sudo pacman -Syyuu --noconfirm
fi
