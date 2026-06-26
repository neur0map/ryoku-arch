#!/usr/bin/env bash
# Hermetic test for ryoku/hyprland/scripts/stash-install.sh. The stash makes
# dropped files launchable: AppImages and self-contained tarballs get a
# synthesized desktop entry, while an Arch package (.pkg.tar.zst, recognised by
# its .PKGINFO member) must be handed to `pacman -U` via pkexec, never extracted
# into ~/.local where its /opt-based binary would not work. pkexec and pacman are
# stubbed, so this asserts the dispatch without touching the real system.
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT/ryoku/hyprland/scripts/stash-install.sh"
[[ -f $SCRIPT ]] || { echo "::error::missing $SCRIPT" >&2; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fail=0
check() { if [[ $1 == "$2" ]]; then echo "  ok: $3"; else echo "::error::FAIL: $3 (got '$1' want '$2')" >&2; fail=1; fi; }
present() { if [[ -e $1 ]]; then echo "  ok: $2"; else echo "::error::FAIL: $2 (missing $1)" >&2; fail=1; fi; }
absent()  { if [[ ! -e $1 ]]; then echo "  ok: $2"; else echo "::error::FAIL: $2 ($1 exists)" >&2; fail=1; fi; }

# Stubs: pkexec records its args so we can assert the escalation; pacman,
# notify-send and update-desktop-database only need to exist for the script's
# presence checks.
stub="$work/bin"
mkdir -p "$stub"
cat >"$stub/pkexec" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$work/pkexec.log"
exit 0
EOF
for t in pacman notify-send update-desktop-database; do printf '#!/bin/sh\nexit 0\n' >"$stub/$t"; done
chmod +x "$stub"/*
export PATH="$stub:$PATH"

# A fake Arch package: a tar carrying a top-level .PKGINFO (pkgname=$2). gz so the
# test needs no zstd; classify keys on the .pkg.tar. infix or the .PKGINFO member.
mkpkg() {
  local out="$1" name="$2" d="$work/pkgsrc"
  rm -rf "$d"; mkdir -p "$d"
  printf 'pkgname = %s\npkgver = 1-1\n' "$name" >"$d/.PKGINFO"
  ( cd "$d" && tar -czf "$out" .PKGINFO )
}

run_stash() {
  rm -rf "${work:?}/home"
  HOME="$work/home" bash "$SCRIPT" >"$work/out" 2>&1
}

# Case 1: a .pkg.tar.* package is installed via pkexec pacman -U, not extracted.
s1="$work/stash1"; mkdir -p "$s1"
mkpkg "$s1/foo.pkg.tar.gz" foo
: >"$work/pkexec.log"
STASH_DIR="$s1" run_stash
if grep -q "Installed foo" "$work/out"; then
  echo "  ok: reported the pkgname (foo)"
else
  echo "::error::FAIL: did not report pkgname; out: $(cat "$work/out")" >&2
  fail=1
fi
check "$(cat "$work/pkexec.log")" "pacman -U --noconfirm $s1/foo.pkg.tar.gz" \
  "pacman package handed to pkexec pacman -U"
absent "$work/home/.local/share/ryoku-apps/foo" "pacman package NOT extracted into ~/.local"

# Case 2: a renamed package (.tar.gz with .PKGINFO) is still detected as pacman.
s2="$work/stash2"; mkdir -p "$s2"
mkpkg "$s2/bar.tar.gz" bar
: >"$work/pkexec.log"
STASH_DIR="$s2" run_stash
check "$(cat "$work/pkexec.log")" "pacman -U --noconfirm $s2/bar.tar.gz" \
  "renamed Arch package detected by .PKGINFO and sent to pacman"

# Case 3: a generic tarball (no .PKGINFO) stays the extract path, never pacman.
s3="$work/stash3"; mkdir -p "$s3"
g="$work/gen"; rm -rf "$g"; mkdir -p "$g"
printf '#!/bin/sh\necho hi\n' >"$g/plainbin"; chmod +x "$g/plainbin"
( cd "$g" && tar -czf "$s3/plainapp.tar.gz" plainbin )
: >"$work/pkexec.log"
STASH_DIR="$s3" run_stash
check "$(cat "$work/pkexec.log")" "" "generic tarball never escalated to pacman"
present "$work/home/.local/share/applications/plainapp.desktop" \
  "generic tarball still becomes a launcher entry"

if (( fail )); then echo "stash-install: FAILED" >&2; exit 1; fi
echo "stash-install: all checks passed"
