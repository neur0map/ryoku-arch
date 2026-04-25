#!/bin/bash
# Install the AUR-only packages that used to come from the [omarchy]
# pacman repo. After Path A dropped the repo, these are pulled from
# AUR instead so the install flow still converges without touching
# DHH-hosted infrastructure.
#
# Packages intentionally excluded:
#   asdcontrol                     Apple display brightness (only useful
#                                  with Apple USB-C displays; kept on
#                                  live systems but not reinstalled).
#   hyprland-preview-share-picker  Screen-share visual picker; we accepted
#                                  the feature loss when the omarchy repo
#                                  left.
#   tobi-try                       Unknown provenance; dropped.

if ! ryoku-pkg-aur-accessible; then
  echo "AUR unavailable, skipping AUR-core install"
  return 1 2>/dev/null || exit 1
fi

ryoku-pkg-aur-add \
  1password-beta \
  1password-cli \
  aether \
  claude-code \
  limine-mkinitcpio-hook \
  limine-snapper-sync \
  localsend \
  pinta \
  python-terminaltexteffects \
  spotify \
  ttf-ia-writer \
  typora \
  tzupdate \
  ufw-docker \
  xdg-terminal-exec \
  yaru-icon-theme
