# Install all base packages
mapfile -t packages < <(grep -v '^#' "$RYOKU_INSTALL/ryoku-base.packages" | grep -v '^$')
ryoku-pkg-add "${packages[@]}"
