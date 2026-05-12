#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin" "$tmp/conflicts/usr/share/example" "$tmp/backups"
touch "$tmp/conflicts/usr/share/example/payload.sh"

cat >"$tmp/update.log" <<LOG
error: failed to commit transaction (conflicting files)
example-tool: $tmp/conflicts/usr/share/example/payload.sh exists in filesystem
Errors occurred, no packages were upgraded.
LOG

cat >"$tmp/bin/pacman" <<'PACMAN'
#!/bin/bash

case "${1:-}" in
  -Qo)
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
RYOKU_UPDATE_LOG="$tmp/update.log" \
RYOKU_PACMAN_CONFLICT_BACKUP_DIR="$tmp/backups" \
RYOKU_TEST_PACMAN_UPDATE="$tmp/pacman-update" \
PATH="$tmp/bin:$PATH" \
  "$ROOT_DIR/bin/ryoku-update-system-pkgs"

[[ ! -e $tmp/conflicts/usr/share/example/payload.sh ]] \
  || fail "generic unowned conflict file should be moved before pacman update"
find "$tmp/backups" -path '*/payload.sh' -print -quit | grep -q . \
  || fail "generic unowned conflict file should be preserved in conflict backups"
grep -Fx -- "-Syu --noconfirm" "$tmp/pacman-update" >/dev/null \
  || fail "system package update should still run after conflict cleanup"

echo "PASS: update system package generic file conflict cleanup"

rm -rf "$tmp/conflicts" "$tmp/backups"
mkdir -p "$tmp/conflicts/usr/lib/node_modules/semver/functions" "$tmp/backups"
touch "$tmp/conflicts/usr/lib/node_modules/semver/functions/truncate.js"

cat >"$tmp/update.log" <<'LOG'
error: failed to commit transaction (conflicting files)
semver: /usr/lib/node_modules/semver/functions/truncate.js exists in filesystem
Errors occurred, no packages were upgraded.
LOG

cat >"$tmp/bin/pacman" <<'PACMAN'
#!/bin/bash

case "${1:-}" in
  -Qo)
    [[ ${2:-} == "$RYOKU_SYSTEM_NODE_MODULES_DIR/semver" ]] && exit 0
    [[ ${2:-} == "$RYOKU_SYSTEM_NODE_MODULES_DIR/semver/functions/truncate.js" ]] && exit 1
    exit 1
    ;;
  -Syu)
    printf '%s\n' "$*" >"$RYOKU_TEST_PACMAN_UPDATE"
    exit 0
    ;;
esac

exit 2
PACMAN

RYOKU_PATH="$ROOT_DIR" \
RYOKU_UPDATE_LOG="$tmp/update.log" \
RYOKU_SYSTEM_NODE_MODULES_DIR="$tmp/conflicts/usr/lib/node_modules" \
RYOKU_PACMAN_CONFLICT_BACKUP_DIR="$tmp/backups" \
RYOKU_TEST_PACMAN_UPDATE="$tmp/pacman-update" \
PATH="$tmp/bin:$PATH" \
  "$ROOT_DIR/bin/ryoku-update-system-pkgs"

[[ -d $tmp/conflicts/usr/lib/node_modules/semver ]] \
  || fail "owned semver package directory should stay in place"
[[ ! -e $tmp/conflicts/usr/lib/node_modules/semver/functions/truncate.js ]] \
  || fail "unowned semver conflict file should be moved before pacman update"
find "$tmp/backups" -path '*/truncate.js' -print -quit | grep -q . \
  || fail "unowned semver conflict file should be preserved in conflict backups"
grep -Fx -- "-Syu --noconfirm" "$tmp/pacman-update" >/dev/null \
  || fail "system package update should still run after owned-package conflict cleanup"

echo "PASS: update system package owned semver file conflict cleanup"
