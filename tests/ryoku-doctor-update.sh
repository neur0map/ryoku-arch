#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin" "$tmp/fake-ryoku/bin" "$tmp/conflicts/usr/share/example" "$tmp/backups" "$tmp/state/quickshell/user"
touch "$tmp/conflicts/usr/share/example/payload.sh"

cat >"$tmp/update.log" <<LOG
warning: archlinux-keyring-20260420-1 is up to date -- skipping
error: failed to commit transaction (conflicting files)
example-tool: $tmp/conflicts/usr/share/example/payload.sh exists in filesystem
Errors occurred, no packages were upgraded.
LOG

cat >"$tmp/bin/pacman" <<'PACMAN'
#!/bin/bash

case "${1:-}" in
  -Q)
    exit 0
    ;;
  -Qo)
    exit 1
    ;;
esac

exit 2
PACMAN

cat >"$tmp/bin/sudo" <<'SUDO'
#!/bin/bash

"$@"
SUDO

chmod 755 "$tmp/bin/pacman" "$tmp/bin/sudo"
ln -s "$ROOT_DIR/bin/ryoku-doctor" "$tmp/bin/ryoku-doctor-link"
ln -s "$ROOT_DIR/bin/ryoku-update" "$tmp/bin/ryoku-update-link"

cat >"$tmp/fake-ryoku/bin/ryoku-update-confirm" <<'CONFIRM'
#!/bin/bash

exit 1
CONFIRM

chmod 755 "$tmp/fake-ryoku/bin/ryoku-update-confirm"

"$tmp/bin/ryoku-doctor-link" -h | grep -Fq 'ryoku-doctor [apps|ff|update|-h]' \
  || fail "ryoku-doctor should resolve its repo root when called through a symlink"

git init -b main "$tmp/source" >/dev/null
git -C "$tmp/source" config user.email "doctor-test@example.invalid"
git -C "$tmp/source" config user.name "Doctor Test"
mkdir -p "$tmp/source/bin"
cat >"$tmp/source/bin/ryoku-update-git" <<'UPDATE_GIT'
#!/bin/bash

git -C "$RYOKU_PATH" fetch origin main >/dev/null 2>&1
git -C "$RYOKU_PATH" merge --ff-only origin/main >/dev/null
UPDATE_GIT
chmod 755 "$tmp/source/bin/ryoku-update-git"
git -C "$tmp/source" add bin/ryoku-update-git
git -C "$tmp/source" commit -m "base" >/dev/null
git clone --bare "$tmp/source" "$tmp/remote.git" >/dev/null 2>&1
git clone "$tmp/remote.git" "$tmp/checkout" >/dev/null 2>&1
git clone "$tmp/remote.git" "$tmp/checkout-offer" >/dev/null 2>&1
git -C "$tmp/source" remote add origin "$tmp/remote.git"
echo "future recovery fix" >"$tmp/source/recovery.txt"
git -C "$tmp/source" add recovery.txt
git -C "$tmp/source" commit -m "future recovery fix" >/dev/null
git -C "$tmp/source" push origin main >/dev/null 2>&1

RYOKU_PATH="$tmp/checkout" \
RYOKU_UPDATE_REMOTE_URL="$tmp/remote.git" \
  "$ROOT_DIR/bin/ryoku-doctor" ff >/dev/null \
  || fail "ryoku-doctor ff should fast-forward to the latest release branch"
git -C "$tmp/checkout" merge-base --is-ancestor origin/main HEAD \
  || fail "ryoku-doctor ff should leave checkout at origin/main"

RYOKU_UPDATE_INHIBITED=1 \
RYOKU_UPDATE_LOGGED=1 \
RYOKU_UPDATE_POWER_CHECKED=1 \
RYOKU_PATH="$tmp/fake-ryoku" \
PATH="$tmp/bin:$PATH" \
  "$tmp/bin/ryoku-update-link" \
  || fail "ryoku-update should resolve its repo root when called through a symlink"

output=$(
  RYOKU_PATH="$tmp/checkout-offer" \
  RYOKU_UPDATE_REMOTE_URL="$tmp/remote.git" \
  RYOKU_DOCTOR_ASSUME_NO=1 \
  RYOKU_UPDATE_LOG="$tmp/update.log" \
  RYOKU_PACMAN_CONFLICT_BACKUP_DIR="$tmp/backups" \
  XDG_STATE_HOME="$tmp/state" \
  PATH="$tmp/bin:$PATH" \
    "$ROOT_DIR/bin/ryoku-doctor" update 2>&1
) || fail "ryoku-doctor update should repair generic pacman file conflicts: $output"

[[ ! -e $tmp/conflicts/usr/share/example/payload.sh ]] \
  || fail "doctor should move an unowned generic conflict file"
find "$tmp/backups" -path '*/payload.sh' -print -quit | grep -q . \
  || fail "doctor should preserve moved generic conflict files"
grep -Fq 'Detected pacman file conflicts.' <<<"$output" \
  || fail "doctor should identify generic pacman file conflicts"
grep -Fq 'A newer Ryoku recovery update is available' <<<"$output" \
  || fail "doctor should offer a fast-forward when a newer release is available"
grep -Fq 'Fast-forward Ryoku now? [Y/n] n' <<<"$output" \
  || fail "doctor should allow users to skip the fast-forward"
grep -Fq 'Run: ryoku-update -y' <<<"$output" \
  || fail "doctor should tell users the short retry command"
if grep -Fq 'package signature or keyring issue' <<<"$output"; then
  fail "doctor should not warn on normal archlinux-keyring update lines"
fi

echo "PASS: ryoku-doctor update repairs generic pacman conflict"

rm -rf "$tmp/conflicts" "$tmp/backups"
mkdir -p "$tmp/conflicts/usr/lib/node_modules/semver/functions" "$tmp/backups"
touch "$tmp/conflicts/usr/lib/node_modules/semver/functions/truncate.js"

cat >"$tmp/update.log" <<LOG
error: failed to commit transaction (conflicting files)
semver: /usr/lib/node_modules/semver/functions/truncate.js exists in filesystem
Errors occurred, no packages were upgraded.
LOG

cat >"$tmp/bin/pacman" <<'PACMAN'
#!/bin/bash

case "${1:-}" in
  -Q)
    [[ ${2:-} == "semver" ]] && exit 0
    exit 1
    ;;
  -Qo)
    [[ ${2:-} == "$RYOKU_SYSTEM_NODE_MODULES_DIR/semver" ]] && exit 0
    [[ ${2:-} == "$RYOKU_SYSTEM_NODE_MODULES_DIR/semver/functions/truncate.js" ]] && exit 1
    exit 1
    ;;
esac

exit 2
PACMAN

output=$(
  RYOKU_PATH="$tmp/fake-ryoku" \
  RYOKU_UPDATE_LOG="$tmp/update.log" \
  RYOKU_SYSTEM_NODE_MODULES_DIR="$tmp/conflicts/usr/lib/node_modules" \
  RYOKU_PACMAN_CONFLICT_BACKUP_DIR="$tmp/backups" \
  XDG_STATE_HOME="$tmp/state" \
  PATH="$tmp/bin:$PATH" \
    "$ROOT_DIR/bin/ryoku-doctor" update 2>&1
) || fail "ryoku-doctor update should repair an unowned file inside pacman-owned semver: $output"

[[ -d $tmp/conflicts/usr/lib/node_modules/semver ]] || fail "doctor should not move pacman-owned semver directory"
[[ ! -e $tmp/conflicts/usr/lib/node_modules/semver/functions/truncate.js ]] \
  || fail "doctor should move unowned conflict files inside pacman-owned semver"
find "$tmp/backups" -path '*/truncate.js' -print -quit | grep -q . \
  || fail "doctor should preserve the moved semver conflict file"
grep -Fq 'Run: ryoku-update -y' <<<"$output" \
  || fail "doctor should still tell users the short retry command"

echo "PASS: ryoku-doctor update repairs owned semver file conflict"

rm -rf "$tmp/conflicts" "$tmp/backups"
mkdir -p "$tmp/conflicts/usr/lib/node_modules/semver/functions" "$tmp/backups"
touch "$tmp/conflicts/usr/lib/node_modules/semver/functions/truncate.js"

cat >"$tmp/bin/pacman" <<'PACMAN'
#!/bin/bash

case "${1:-}" in
  -Q|-Qo)
    exit 0
    ;;
esac

exit 2
PACMAN

output=$(
  RYOKU_PATH="$tmp/fake-ryoku" \
  RYOKU_UPDATE_LOG="$tmp/update.log" \
  RYOKU_SYSTEM_NODE_MODULES_DIR="$tmp/conflicts/usr/lib/node_modules" \
  RYOKU_PACMAN_CONFLICT_BACKUP_DIR="$tmp/backups" \
  XDG_STATE_HOME="$tmp/state" \
  PATH="$tmp/bin:$PATH" \
    "$ROOT_DIR/bin/ryoku-doctor" update 2>&1
) || fail "ryoku-doctor update should allow retry when conflict paths are already pacman-owned: $output"

[[ -e $tmp/conflicts/usr/lib/node_modules/semver/functions/truncate.js ]] \
  || fail "doctor should not move pacman-owned conflict files"
grep -Fq 'Path is owned by pacman, leaving it in place' <<<"$output" \
  || fail "doctor should report pacman-owned conflict files"
grep -Fq 'Run: ryoku-update -y' <<<"$output" \
  || fail "doctor should still tell users to retry when conflict files are already owned"

echo "PASS: ryoku-doctor update handles already-owned semver"
