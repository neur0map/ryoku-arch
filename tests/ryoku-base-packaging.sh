#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

grep -qxF dosfstools "$ROOT_DIR/install/ryoku-base.packages" || \
  fail "Ryoku base packages should include dosfstools for FAT EFI boot recovery"

grep -qxF nodejs "$ROOT_DIR/install/ryoku-base.packages" || \
  fail "Ryoku base packages should include nodejs for shipped JavaScript tooling"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin" "$tmp/install"

cat > "$tmp/install/ryoku-base.packages" <<'PACKAGES'
bash
quickshell
jq
PACKAGES

cat > "$tmp/bin/pacman" <<'PACMAN'
#!/bin/bash

if [[ ${1:-} == "-T" ]]; then
  shift
  for dep in "$@"; do
    [[ $dep == "quickshell" ]] && continue
    printf '%s\n' "$dep"
  done
  exit 127
fi

exit 2
PACMAN

cat > "$tmp/bin/ryoku-pkg-add" <<'PKGADD'
#!/bin/bash

printf '%s\n' "$@" > "$RYOKU_TEST_PKG_ADD_ARGS"
PKGADD

cat > "$tmp/bin/ryoku-cmd-present" <<'CMDPRESENT'
#!/bin/bash

command -v "$1" >/dev/null 2>&1
CMDPRESENT

chmod 755 "$tmp/bin/pacman" "$tmp/bin/ryoku-pkg-add" "$tmp/bin/ryoku-cmd-present"

RYOKU_INSTALL="$tmp/install" \
RYOKU_TEST_PKG_ADD_ARGS="$tmp/pkg-add-args" \
PATH="$tmp/bin:$PATH" \
  bash "$ROOT_DIR/install/packaging/base.sh"

[[ -f $tmp/pkg-add-args ]] || fail "base packaging should call ryoku-pkg-add for missing dependencies"

if grep -Fx quickshell "$tmp/pkg-add-args" >/dev/null; then
  fail "base packaging should not request official quickshell when pacman -T says the dependency is already satisfied"
fi

grep -Fx bash "$tmp/pkg-add-args" >/dev/null || fail "base packaging should keep missing package bash"
grep -Fx jq "$tmp/pkg-add-args" >/dev/null || fail "base packaging should keep missing package jq"

echo "PASS: ryoku base packaging dependency filtering"
