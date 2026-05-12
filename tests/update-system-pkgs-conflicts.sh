#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin" "$tmp/node_modules/semver/functions" "$tmp/backups"
touch "$tmp/node_modules/semver/functions/truncate.js"

cat >"$tmp/bin/pacman" <<'PACMAN'
#!/bin/bash

case "${1:-}" in
  -Q|-Qo)
    exit 1
    ;;
  -Syu)
    printf '%s\n' "$*" >"$RYOKU_TEST_PACMAN_UPDATE"
    exit 0
    ;;
esac

exit 2
PACMAN

cat >"$tmp/bin/sudo" <<'SUDO'
#!/bin/bash

"$@"
SUDO

chmod 755 "$tmp/bin/pacman" "$tmp/bin/sudo"

RYOKU_PATH="$ROOT_DIR" \
RYOKU_SYSTEM_NODE_MODULES_DIR="$tmp/node_modules" \
RYOKU_PACMAN_CONFLICT_BACKUP_DIR="$tmp/backups" \
RYOKU_TEST_PACMAN_UPDATE="$tmp/pacman-update" \
PATH="$tmp/bin:$PATH" \
  "$ROOT_DIR/bin/ryoku-update-system-pkgs"

[[ ! -e $tmp/node_modules/semver ]] || fail "unowned semver tree should be moved before pacman update"
find "$tmp/backups" -path '*/semver-*/functions/truncate.js' -print -quit | grep -q . \
  || fail "unowned semver tree should be preserved in conflict backups"
grep -Fx -- "-Syu --noconfirm" "$tmp/pacman-update" >/dev/null \
  || fail "system package update should still run after conflict cleanup"

echo "PASS: update system package conflict cleanup"
