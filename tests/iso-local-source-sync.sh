#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_sync_excludes_release_artifacts_and_git_metadata() {
  local temp_dir source_dir target_dir

  temp_dir=$(mktemp -d)
  source_dir="$temp_dir/source"
  target_dir="$temp_dir/target"
  public_remote="$temp_dir/public-ryoku.git"

  mkdir -p "$source_dir/install" "$source_dir/config" "$source_dir/iso/release" "$source_dir/.git/objects"
  git -C "$source_dir" init >/dev/null
  git -C "$source_dir" remote add origin "git@github.com:private/ryoku-arch.git"
  git -C "$source_dir" config http.https://github.com/.extraheader "AUTHORIZATION: basic stale-token"
  printf '%s\n' "hello" > "$source_dir/install/example.sh"
  printf '%s\n' "config" > "$source_dir/config/example.conf"
  printf '%s\n' "big-image" > "$source_dir/iso/release/ryoku.iso"
  printf '%s\n' "git-object" > "$source_dir/.git/objects/keep-me-out"

  RYOKU_UPDATE_REMOTE_URL="$public_remote" \
    /bin/bash "$ROOT_DIR/iso/builder/sync-local-source.sh" "$source_dir" "$target_dir"

  [[ -f $target_dir/install/example.sh ]] || {
    rm -rf "$temp_dir"
    fail "sync-local-source should copy normal repo files"
  }

  [[ -f $target_dir/config/example.conf ]] || {
    rm -rf "$temp_dir"
    fail "sync-local-source should preserve normal config files"
  }

  [[ ! -e $target_dir/iso/release/ryoku.iso ]] || {
    rm -rf "$temp_dir"
    fail "sync-local-source should exclude iso/release artifacts"
  }

  [[ -f $target_dir/.git/objects/keep-me-out ]] || {
    rm -rf "$temp_dir"
    fail "sync-local-source should preserve git metadata for updateable local-source dev builds"
  }

  [[ $(git -C "$target_dir" remote get-url origin) == "$public_remote" ]] || {
    rm -rf "$temp_dir"
    fail "sync-local-source should normalize copied git origin to the public update remote"
  }

  [[ -z $(git -C "$target_dir" config --get-regexp 'extraheader' 2>/dev/null || true) ]] || {
    rm -rf "$temp_dir"
    fail "sync-local-source should remove stale copied GitHub auth headers"
  }

  rm -rf "$temp_dir"
}

assert_sync_excludes_release_artifacts_and_git_metadata

echo "PASS: iso local-source sync tests"
