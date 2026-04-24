#!/bin/bash

# Ryoku Arch online bootstrap. Entry point for curl-to-shell installs.
#
# Fresh-install only. Upgrades go through ryoku-update, not this script.

set -eEo pipefail

export RYOKU_ONLINE_INSTALL=true

ansi_art='
            ████
            ██████
  ██████████████████████████████
  ██████████████████████████████
            ████          ██████
          ██████          ██████
          ████            ████
      ██████              ████
  ████████          ██████████
  ████            ██████████

 ██████╗ ██╗   ██╗ ██████╗ ██╗  ██╗██╗   ██╗
 ██╔══██╗╚██╗ ██╔╝██╔═══██╗██║ ██╔╝██║   ██║
 ██████╔╝ ╚████╔╝ ██║   ██║█████╔╝ ██║   ██║
 ██╔══██╗  ╚██╔╝  ██║   ██║██╔═██╗ ██║   ██║
 ██║  ██║   ██║   ╚██████╔╝██║  ██╗╚██████╔╝
 ╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝ ╚═════╝

            力と美のために  :  For the sake of power and beauty.
'

clear
# Japanese old red #8F1D21 via truecolor ANSI
printf "\033[38;2;143;29;33m%s\033[0m\n" "$ansi_art"

# Channel selection: stable (master), rc (rc branch), dev (dev branch).
# All three currently share the same upstream Arch mirror snapshot; the
# channel concept survives as scaffolding for future differentiation.
RYOKU_REF="${RYOKU_REF:-master}"

case "$RYOKU_REF" in
  dev) export RYOKU_MIRROR=edge ;;
  rc)  export RYOKU_MIRROR=rc ;;
  *)   export RYOKU_MIRROR=stable ;;
esac

# Seed a minimal mirrorlist so the initial sync succeeds before the full
# mirrorlist snapshot is copied into place by install/preflight/pacman.sh.
if ! sudo test -s /etc/pacman.d/mirrorlist; then
  echo 'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch' | sudo tee /etc/pacman.d/mirrorlist >/dev/null
fi

sudo pacman -Syu --noconfirm --needed git

RYOKU_REPO="${RYOKU_REPO:-neur0map/ryoku-arch}"

echo -e "\nCloning Ryoku Arch from: https://github.com/${RYOKU_REPO}.git"
rm -rf "$HOME/.local/share/ryoku"
# If the legacy path exists from a pre-rename checkout, take it out of
# the way so git clone does not fight a stale tree. Upgrades from an
# existing install go through migrations, not this script.
rm -rf "$HOME/.local/share/omarchy"
git clone "https://github.com/${RYOKU_REPO}.git" "$HOME/.local/share/ryoku" >/dev/null

echo -e "\e[32mUsing branch: $RYOKU_REF\e[0m"
cd "$HOME/.local/share/ryoku"
git fetch origin "${RYOKU_REF}" && git checkout "${RYOKU_REF}"
cd - >/dev/null

echo -e "\nInstallation starting..."
source "$HOME/.local/share/ryoku/install.sh"
