#!/bin/bash

set -euo pipefail

if (($# != 2)); then
  echo "Usage: $0 <source_dir> <target_dir>" >&2
  exit 1
fi

source_dir="$1"
target_dir="$2"

mkdir -p "$target_dir"

# Keep .git so the installed system's ~/.local/share/ryoku is a real
# git repo with origin already set. Without this, ryoku-update fails
# with "fatal: not a git repository" because the source was tar-copied
# instead of git-cloned. Production ISOs (built via git clone) already
# preserve .git through cp -r; --local-source dev builds need this
# explicit pass-through to match. omarchy and Ryoku's boot.sh online
# path both rely on the source dir being a real git checkout so that
# `git pull` works without a GitHub account (public HTTPS origin needs
# no auth).
tar -C "$source_dir" \
  --exclude='./iso/release' \
  --exclude='./iso/release/*' \
  -cf - . | tar -C "$target_dir" -xf -
