#!/bin/bash

# Ryoku Shell online bootstrap (experimental). Clones the repo and runs the
# shell installer. This is the shell-layer counterpart to the OS installer's
# boot.sh; it never touches the bootloader, filesystem, or display manager.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/neur0map/ryoku-arch/main/shell-install/boot.sh)
#
# Pass-through flags reach shell-install/install, e.g. --dry-run / --yes.

set -eEo pipefail

RYOKU_REPO="${RYOKU_REPO:-https://github.com/neur0map/ryoku-arch.git}"
# The shell-only branch (Option A: generated = main minus iso/). Non-Arch users
# get just the shell, not the ISO builder. See docs/ryoku-shell-branch.md.
RYOKU_REF="${RYOKU_REF:-ryoku-shell}"

if (( EUID == 0 )); then
  echo "Run this as your normal user, not root." >&2
  exit 1
fi

command -v git >/dev/null 2>&1 || { echo "git is required. Install it first: sudo pacman -S git" >&2; exit 1; }

clone_dir="$(mktemp -d)"
trap 'rm -rf "$clone_dir"' EXIT

echo ":: cloning $RYOKU_REPO ($RYOKU_REF)"
git clone --depth 1 --branch "$RYOKU_REF" "$RYOKU_REPO" "$clone_dir/ryoku-arch"

exec bash "$clone_dir/ryoku-arch/shell-install/install" "$@"
