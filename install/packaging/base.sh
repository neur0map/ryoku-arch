# Install all base packages
mapfile -t packages < <(grep -v '^#' "$RYOKU_INSTALL/ryoku-base.packages" | grep -v '^$')

if ryoku-cmd-present pacman; then
  mapfile -t packages < <(pacman -T "${packages[@]}")
fi

if (( ${#packages[@]} == 0 )); then
  exit 0
fi

ryoku-pkg-add "${packages[@]}"
