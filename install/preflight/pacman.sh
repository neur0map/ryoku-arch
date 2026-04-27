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

  # When installing from the live ISO, the offline boot overlay
  # (limine-mkinitcpio-hook, limine-snapper-sync) is bind-mounted into
  # the chroot. Re-attach it as a temporary [offline] repo so
  # packaging/base.sh can pacman-install those AUR-built packages from
  # ryoku-base.packages. post-install/pacman.sh re-copies the clean
  # upstream-only pacman.conf at install end, so this entry never
  # leaks onto the user's installed system.
  if [[ -d /var/cache/ryoku/mirror/offline ]]; then
    cat <<'EOF' | sudo tee -a /etc/pacman.conf >/dev/null

[offline]
SigLevel = Optional TrustAll
Server = file:///var/cache/ryoku/mirror/offline/
EOF
  fi

  # Refresh all repos (archlinux-keyring ships the only keys we consume).
  sudo pacman -Syyuu --noconfirm
fi
