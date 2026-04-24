#!/bin/bash

# Ryoku Arch online bootstrap. Entry point for curl-to-shell installs.
#
# Fresh-install only. Upgrades go through ryoku-update, not this script.

set -eEo pipefail

export RYOKU_ONLINE_INSTALL=true

# Banner art: 力 kanji block rendering adapted from branding/about.txt
# (frame stripped), followed by the RYOKU wordmark in Unicode box-drawing
# and the tagline. All in Ryoku accent orange #F25623 except the tagline,
# which uses the theme's subdued foreground #aeab94.
kanji_art='
                   ████████
                   ████████
                   ████████
                   ████████
     ██████████████████████████████████████████
   ██████████████████████████████████████████████
   ██████████████████████████████████████████████
                   ████████              ████████
                   ██████                ██████
                   ██████                ██████
                 ████████                ██████
                 ████████                ██████
               ████████                  ██████
             ██████████                  ██████
             ████████                  ████████
         ██████████                    ████████
       ██████████                      ██████
   ████████████              ████████████████
   ████████                  ██████████████
     ████                      ████████
'

wordmark='
 ██████╗ ██╗   ██╗ ██████╗ ██╗  ██╗██╗   ██╗
 ██╔══██╗╚██╗ ██╔╝██╔═══██╗██║ ██╔╝██║   ██║
 ██████╔╝ ╚████╔╝ ██║   ██║█████╔╝ ██║   ██║
 ██╔══██╗  ╚██╔╝  ██║   ██║██╔═██╗ ██║   ██║
 ██║  ██║   ██║   ╚██████╔╝██║  ██╗╚██████╔╝
 ╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝ ╚═════╝
'

tagline='            力と美のために  :  For the sake of power and beauty.'

clear
# Orange #F25623 for kanji and wordmark; subdued foreground #aeab94 for
# tagline so the brand mark reads as the focal point.
printf '\033[38;2;242;86;35m%s%s\033[0m\n' "$kanji_art" "$wordmark"
printf '\033[38;2;174;171;148m%s\033[0m\n\n' "$tagline"

# Branch selection. Default to main (the repo's default branch). Users
# can override with RYOKU_REF=<branch> when calling boot.sh. No mirror
# variable: Ryoku does not operate named mirrors; the legacy
# RYOKU_MIRROR block was dead code inherited from Omarchy.
RYOKU_REF="${RYOKU_REF:-main}"

# Seed a minimal mirrorlist so the initial sync succeeds before the full
# mirrorlist snapshot is copied into place by install/preflight/pacman.sh.
if ! sudo test -s /etc/pacman.d/mirrorlist; then
  echo 'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch' | sudo tee /etc/pacman.d/mirrorlist >/dev/null
fi

sudo pacman -Syu --noconfirm --needed git

RYOKU_REPO="${RYOKU_REPO:-neur0map/ryoku-arch}"

echo -e "\nCloning Ryoku Arch from: https://github.com/${RYOKU_REPO}.git"

# If the pre-rename ~/.local/share/omarchy is a real directory (legacy
# Omarchy install), archive it by renaming so the user keeps their git
# history and local commits. If it is a symlink (the post-rename
# compat shim) or absent, leave it alone.
OMARCHY_DIR="$HOME/.local/share/omarchy"
if [[ -d $OMARCHY_DIR && ! -L $OMARCHY_DIR ]]; then
  MIGRATED_DIR="$HOME/.local/share/ryoku.migrated-$(date +%s)"
  mv "$OMARCHY_DIR" "$MIGRATED_DIR"
  echo "Archived legacy ~/.local/share/omarchy to $MIGRATED_DIR"
fi

# boot.sh is a fresh-install entrypoint. For upgrades, use ryoku-update,
# which preserves the local clone and applies migrations. Re-running
# boot.sh on an installed system will destroy the local clone.
rm -rf "$HOME/.local/share/ryoku"
git clone "https://github.com/${RYOKU_REPO}.git" "$HOME/.local/share/ryoku" >/dev/null

echo -e "\e[32mUsing branch: $RYOKU_REF\e[0m"
cd "$HOME/.local/share/ryoku"
git fetch origin "${RYOKU_REF}" && git checkout "${RYOKU_REF}"
cd - >/dev/null

echo -e "\nInstallation starting..."
source "$HOME/.local/share/ryoku/install.sh"
