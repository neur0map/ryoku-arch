#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
NAMESPACE_MIGRATION="$ROOT_DIR/migrations/1776912972.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_namespace_migration_does_not_self_link_state() {
  local temp_dir home_dir

  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"

  mkdir -p "$home_dir/.local/state/omarchy/migrations" "$home_dir/.config/omarchy"
  touch "$home_dir/.local/state/omarchy/migrations/1751134560.sh"
  printf 'legacy config\n' > "$home_dir/.config/omarchy/example.conf"

  HOME="$home_dir" /bin/bash "$NAMESPACE_MIGRATION" >/dev/null

  [[ -d $home_dir/.local/state/ryoku ]] \
    || fail "state namespace migration should leave ryoku state as a directory"
  [[ ! -L $home_dir/.local/state/ryoku ]] \
    || fail "state namespace migration should not symlink ryoku state to itself"
  [[ -f $home_dir/.local/state/ryoku/migrations/1751134560.sh ]] \
    || fail "state namespace migration should copy legacy migration markers"

  [[ -d $home_dir/.config/ryoku ]] \
    || fail "state namespace migration should leave ryoku config as a directory"
  [[ ! -L $home_dir/.config/ryoku ]] \
    || fail "state namespace migration should not symlink ryoku config to itself"
  [[ -f $home_dir/.config/ryoku/example.conf ]] \
    || fail "state namespace migration should copy legacy config"

  rm -rf "$temp_dir"
}

assert_migrate_repairs_self_linked_state_root() {
  local temp_dir home_dir ryoku_dir state_root

  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  ryoku_dir="$temp_dir/ryoku"
  state_root="$home_dir/.local/state/ryoku"

  mkdir -p "$home_dir/.local/state" "$ryoku_dir/bin" "$ryoku_dir/lib" "$ryoku_dir/migrations"
  ln -s "$state_root" "$state_root"

  cp "$ROOT_DIR/bin/ryoku-migrate" "$ryoku_dir/bin/ryoku-migrate"
  cp "$ROOT_DIR/lib/runtime-env.sh" "$ryoku_dir/lib/runtime-env.sh"
  cp "$ROOT_DIR/lib/update-dashboard.sh" "$ryoku_dir/lib/update-dashboard.sh"

  cat > "$ryoku_dir/migrations/9999999999.sh" <<'MIGRATION'
echo "No-op migration"
MIGRATION

  chmod 755 "$ryoku_dir/bin/ryoku-migrate"

  HOME="$home_dir" \
    RYOKU_PATH="$ryoku_dir" \
    /bin/bash "$ryoku_dir/bin/ryoku-migrate" >/dev/null

  [[ -d $state_root ]] || fail "ryoku-migrate should recreate self-linked state root as a directory"
  [[ ! -L $state_root ]] || fail "ryoku-migrate should remove self-linked state root"
  [[ -f $state_root/migrations/9999999999.sh ]] \
    || fail "ryoku-migrate should record migration markers after repairing state root"

  rm -rf "$temp_dir"
}

assert_namespace_migration_does_not_self_link_state
assert_migrate_repairs_self_linked_state_root

echo "PASS: Ryoku state namespace migration safety"
