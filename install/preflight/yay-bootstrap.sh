#!/bin/bash
# Bootstrap yay (AUR helper) from source. We pulled yay out of
# ryoku-base.packages because it is AUR-only and pacman cannot install it
# directly. base.sh would fail on `pacman -S yay` if the AUR helper is
# absent, so we build it here, before any AUR-dependent step runs.

set -e

if command -v yay >/dev/null; then
  echo "yay already installed"
  exit 0
fi

ryoku-pkg-add base-devel git

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Clone yay-bin from AUR with retries. AUR is occasionally flaky and a
# transient network blip should not abort the whole install.
clone_ok=0
for attempt in 1 2 3; do
  rm -rf "$work/yay-bin"
  if git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$work/yay-bin"; then
    clone_ok=1
    break
  fi
  echo "git clone of yay-bin failed (attempt $attempt/3), retrying in 5s..."
  sleep 5
done

if (( clone_ok == 0 )); then
  echo "ERROR: failed to clone yay-bin from AUR after 3 attempts" >&2
  exit 1
fi

cd "$work/yay-bin"
makepkg -si --noconfirm

command -v yay >/dev/null
