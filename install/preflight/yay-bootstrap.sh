#!/bin/bash
# Bootstrap yay (AUR helper) from source. We pulled yay out of
# ryoku-base.packages because it is AUR-only and pacman cannot install it
# directly. base.sh would fail on `pacman -S yay` if the AUR helper is
# absent, so we build it here, before any AUR-dependent step runs.

if command -v yay >/dev/null; then
  echo "yay already installed"
  return 0 2>/dev/null || exit 0
fi

ryoku-pkg-add base-devel git

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$work/yay-bin"
(
  cd "$work/yay-bin"
  makepkg -si --noconfirm
)

command -v yay >/dev/null
