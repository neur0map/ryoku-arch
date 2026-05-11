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
# git repo. Without this, ryoku-update fails with "fatal: not a git
# repository" because the source was tar-copied instead of git-cloned.
# Production ISOs (built via git clone) already preserve .git through
# cp -r; --local-source dev builds need this explicit pass-through to
# match. Normalize origin after copying so hardware test installs do
# not inherit the builder machine's private fork or stale remote.
tar -C "$source_dir" \
  --exclude='./iso/release' \
  --exclude='./iso/release/*' \
  -cf - . | tar -C "$target_dir" -xf -

update_remote="${RYOKU_UPDATE_REMOTE_URL:-https://github.com/neur0map/ryoku-arch.git}"

if [[ -d $target_dir/.git ]] && git -C "$target_dir" rev-parse --git-dir >/dev/null 2>&1; then
  if git -C "$target_dir" remote get-url origin >/dev/null 2>&1; then
    git -C "$target_dir" remote set-url origin "$update_remote"
  else
    git -C "$target_dir" remote add origin "$update_remote"
  fi
fi
