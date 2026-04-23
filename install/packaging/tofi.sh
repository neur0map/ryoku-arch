#!/bin/bash
# Install tofi (launcher) from AUR.
# Gated on AUR availability so the chroot preflight does not stall
# when offline.

if ! ryoku-pkg-aur-accessible; then
  echo "AUR unavailable, skipping tofi/bemoji install"
  return 1 2>/dev/null || exit 1
fi

ryoku-pkg-aur-add tofi
