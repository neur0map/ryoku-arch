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
# can override with RYOKU_REF=<branch> when calling boot.sh. Package and
# ISO publishing use the single main channel.
RYOKU_REF="${RYOKU_REF:-main}"

# Seed a minimal mirrorlist so the initial sync succeeds before the full
# mirrorlist snapshot is copied into place by install/preflight/pacman.sh.
if ! sudo test -s /etc/pacman.d/mirrorlist; then
  echo 'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch' | sudo tee /etc/pacman.d/mirrorlist >/dev/null
fi

sudo pacman -Syu --noconfirm --needed git

RYOKU_REPO="${RYOKU_REPO:-neur0map/ryoku-arch}"

echo -e "\nCloning Ryoku Arch from: https://github.com/${RYOKU_REPO}.git"

# Detect existing Omarchy install. If found, snapshot the system with
# snapper before overlaying Ryoku, and record snapshot ids so the user
# can `ryoku-rollback` from the menu (Update > Rollback) to restore
# their Omarchy state. Best-effort: if snapper or btrfs is missing the
# install proceeds without rollback support and the user gets a warning.
OMARCHY_DIR="$HOME/.local/share/omarchy"
omarchy_present=false
if [[ -d $OMARCHY_DIR && ! -L $OMARCHY_DIR ]] || \
   [[ -d $HOME/.config/omarchy ]] || \
   [[ -f /etc/omarchy-release ]]; then
  omarchy_present=true
fi

if [[ $omarchy_present == true ]]; then
  echo -e "\n\033[38;2;242;86;35mExisting Omarchy install detected.\033[0m"
  STATE_DIR="$HOME/.local/state/ryoku"
  mkdir -p "$STATE_DIR"

  if command -v snapper >/dev/null; then
    echo "Creating snapshots so you can roll back to Omarchy if you change your mind..."
    ROOT_SNAP=$(sudo snapper -c root create --print-number \
      --description "pre-ryoku-migration" \
      --userdata "ryoku=migration" 2>/dev/null) || ROOT_SNAP=""
    HOME_SNAP=$(sudo snapper -c home create --print-number \
      --description "pre-ryoku-migration" \
      --userdata "ryoku=migration" 2>/dev/null) || HOME_SNAP=""

    if [[ -n $ROOT_SNAP || -n $HOME_SNAP ]]; then
      cat > "$STATE_DIR/migration-state.txt" <<STATE
# Created by boot.sh during Omarchy to Ryoku migration.
# Run 'ryoku-rollback' (or Update > Rollback in the Ryoku menu) to
# restore the Omarchy state from these snapshots.
created_at=$(date -Iseconds)
root_snapshot=$ROOT_SNAP
home_snapshot=$HOME_SNAP
STATE
      echo -e "\033[32mRollback point ready.\033[0m"
      echo "  Root snapshot:  ${ROOT_SNAP:-skipped}"
      echo "  Home snapshot:  ${HOME_SNAP:-skipped}"
      echo "  To roll back later: 'ryoku-rollback' (or Update > Rollback)"
    else
      echo -e "\033[33mWarning: snapper did not produce snapshots; rollback will not be available.\033[0m"
    fi
  else
    echo -e "\033[33mWarning: snapper is not installed; cannot create rollback snapshots.\033[0m"
    echo "Install Ryoku will continue, but reverting to Omarchy will require manual recovery."
  fi

  # Archive the legacy Omarchy clone so we keep their git history and
  # local commits accessible at ~/.local/share/ryoku.migrated-* even
  # after Ryoku owns ~/.local/share/ryoku.
  if [[ -d $OMARCHY_DIR && ! -L $OMARCHY_DIR ]]; then
    MIGRATED_DIR="$HOME/.local/share/ryoku.migrated-$(date +%s%N)"
    mv "$OMARCHY_DIR" "$MIGRATED_DIR"
    echo "Archived legacy ~/.local/share/omarchy to $MIGRATED_DIR"
  fi
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
