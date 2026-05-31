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
# Exclude dev-only build artifacts. A --local-source build copies the working
# tree, which can carry a gitignored shell/build/ (or top-level build/) from
# running the shell setup on the dev box. Its CMakeCache pins the source and
# INSTALL_QMLDIR to the dev user's absolute paths (/home/<devuser>/...), so the
# installer would reuse it and deploy the Ryoku QML plugins outside the install
# user's import path, leaving the desktop shell with `module "Ryoku.Config" is
# not installed`. Strip them so every install builds the native modules clean.
tar -C "$source_dir" \
  --exclude='./iso/release' \
  --exclude='./iso/release/*' \
  --exclude='./build' \
  --exclude='./shell/build' \
  --exclude='./CMakeCache.txt' \
  --exclude='./CMakeFiles' \
  --exclude='./shell/CMakeCache.txt' \
  --exclude='./shell/CMakeFiles' \
  -cf - . | tar -C "$target_dir" -xf -

update_remote="${RYOKU_UPDATE_REMOTE_URL:-https://github.com/neur0map/ryoku-arch.git}"

if [[ -d $target_dir/.git ]] && git -C "$target_dir" rev-parse --git-dir >/dev/null 2>&1; then
  if git -C "$target_dir" remote get-url origin >/dev/null 2>&1; then
    git -C "$target_dir" remote set-url origin "$update_remote"
  else
    git -C "$target_dir" remote add origin "$update_remote"
  fi

  while IFS= read -r key; do
    [[ -n $key ]] || continue
    git -C "$target_dir" config --unset-all "$key" || true
  done < <(git -C "$target_dir" config --name-only --get-regexp 'extraheader' 2>/dev/null || true)
fi
