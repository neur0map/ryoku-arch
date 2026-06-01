#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

bash -n "$ROOT_DIR/lib/wallpaper-backends.sh" || fail "wallpaper-backends.sh has a syntax error"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# ryoku_wp_write_type must write type.txt to the SHELL state dir (ryoku-shell/wallpaper),
# the dir the `ryoku` wallpaper/scheme commands and the shell read it from. Writing it to
# the cache dir (RYOKU_STATE_PATH = ~/.local/state/ryoku) left the reader's copy stale and
# broke wallpaper-derived colours.
(
  export XDG_STATE_HOME="$tmp/state"
  export RYOKU_STATE_PATH="$tmp/state/ryoku" # cache dir; wallpaper type/path must NOT land here
  # shellcheck source=/dev/null
  source "$ROOT_DIR/lib/wallpaper-backends.sh"

  got="$(ryoku_wp_state_dir)"
  [[ $got == "$tmp/state/ryoku-shell/wallpaper" ]] || fail "ryoku_wp_state_dir=$got (expected ryoku-shell)"

  ryoku_wp_write_type video
  [[ -f $tmp/state/ryoku-shell/wallpaper/type.txt ]] || fail "type.txt not written to the shell state dir"
  [[ $(cat "$tmp/state/ryoku-shell/wallpaper/type.txt") == video ]] || fail "type.txt content wrong"
  [[ ! -e $tmp/state/ryoku/wallpaper/type.txt ]] || fail "type.txt leaked into the cache state dir"
) || exit 1

# pause/resume must read wallpaper state via the shared helper, not the cache dir.
for s in ryoku-wallpaper-pause ryoku-wallpaper-resume; do
  if rg -q 'RYOKU_STATE_PATH/wallpaper/(type|path)\.txt' "$ROOT_DIR/bin/$s"; then
    fail "$s still reads wallpaper state from the cache dir (RYOKU_STATE_PATH)"
  fi
  rg -q 'ryoku_wp_state_dir' "$ROOT_DIR/bin/$s" || fail "$s should resolve wallpaper state via ryoku_wp_state_dir"
done

# The `ryoku` bridge reads path.txt/type.txt from the same ryoku-shell state dir.
rg -q 'wallpaper_dir="\$state_dir/wallpaper"' "$ROOT_DIR/shell/scripts/ryoku" || fail "ryoku bridge wallpaper_dir moved"
rg -q 'state_dir=.*ryoku-shell' "$ROOT_DIR/shell/scripts/ryoku" || fail "ryoku bridge state_dir is not under ryoku-shell"

echo "PASS: wallpaper type.txt is written and read from the shared ryoku-shell state dir"
