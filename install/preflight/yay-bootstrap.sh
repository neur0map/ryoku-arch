#!/bin/bash
# Bootstrap yay (AUR helper) from source. We pulled yay out of
# ryoku-base.packages because it is AUR-only and pacman cannot install it
# directly. base.sh would fail on `pacman -S yay` if the AUR helper is
# absent, so we build it here, before any AUR-dependent step runs.
#
# Strategy: try AUR first (canonical source), fall back to GitHub release
# tarball (prebuilt binary) when AUR is unreachable. AUR has periodic TLS
# /handshake failures that would otherwise abort the whole install.

set -e

if command -v yay >/dev/null; then
  echo "yay already installed"
  exit 0
fi

if [[ -z ${RYOKU_ONLINE_INSTALL:-} ]]; then
  echo "Offline install, deferring yay bootstrap until network is available"
  exit 0
fi

ryoku-pkg-add base-devel git curl

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Try cloning yay-bin from AUR with retries.
aur_ok=0
for attempt in 1 2 3; do
  rm -rf "$work/yay-bin"
  if git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$work/yay-bin"; then
    aur_ok=1
    break
  fi
  echo "git clone of yay-bin from AUR failed (attempt $attempt/3), retrying in 5s..."
  sleep 5
done

if (( aur_ok == 1 )); then
  cd "$work/yay-bin"
  makepkg -si --noconfirm
else
  echo "AUR unreachable, falling back to yay GitHub release..."
  # GitHub release ships a prebuilt binary; bypasses AUR entirely.
  cd "$work"
  release_url=$(curl -fsSL https://api.github.com/repos/Jguer/yay/releases/latest \
    | grep -oE '"browser_download_url": *"[^"]*x86_64\.tar\.gz"' \
    | head -1 \
    | sed 's/.*: *"\(.*\)"/\1/')
  if [[ -z $release_url ]]; then
    echo "ERROR: could not determine yay GitHub release URL" >&2
    exit 1
  fi
  echo "Downloading $release_url"
  curl -fsSL "$release_url" -o yay.tar.gz
  tar xzf yay.tar.gz
  binary=$(find . -maxdepth 2 -type f -name yay | head -1)
  if [[ -z $binary ]]; then
    echo "ERROR: yay binary not found in tarball" >&2
    exit 1
  fi
  sudo install -m 0755 "$binary" /usr/local/bin/yay
fi

command -v yay >/dev/null
