#!/bin/bash
# Install tofi from AUR. Gated on AUR availability so chroot preflight
# does not stall when offline.

if ! ryoku-pkg-aur-accessible; then
  echo "AUR unavailable, skipping tofi install"
  return 1 2>/dev/null || exit 1
fi

ryoku-pkg-aur-install tofi
