#!/bin/bash
# Install tofi (launcher) from AUR.
# Gated on AUR availability and tolerant of AUR flakiness so a transient
# RPC error does not abort the whole install. tofi is a soft requirement
# for the launcher hotkey; install proceeds with a warning if it fails.

if ! ryoku-pkg-aur-accessible; then
  echo "AUR unavailable, skipping tofi install"
  exit 0
fi

for attempt in 1 2 3; do
  if ryoku-pkg-aur-add tofi; then
    exit 0
  fi
  echo "AUR install of tofi failed (attempt $attempt/3), retrying in 5s..."
  sleep 5
done

echo
echo "WARNING: tofi could not be installed from AUR (transient AUR outage?)."
echo "  Install with 'yay -S tofi' once AUR is reachable. Until then the"
echo "  Super+Space launcher hotkey will not work."
exit 0
