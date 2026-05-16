#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

grep -qxF gpk-bin "$ROOT_DIR/install/ryoku-aur.packages" || \
  fail "Ryoku AUR packages should include gpk-bin for GlazePKG"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin" "$tmp/install"
: > "$tmp/installed"

cat > "$tmp/install/ryoku-aur.packages" <<'PACKAGES'
gradia
quickshell
tofi
PACKAGES

cat > "$tmp/bin/pacman" <<'PACMAN'
#!/bin/bash

is_satisfied() {
  local dep=$1

  if [[ $dep == "quickshell" ]]; then
    return 0
  fi

  grep -Fx "$dep" "$RYOKU_TEST_INSTALLED" >/dev/null
}

if [[ ${1:-} == "-T" ]]; then
  shift
  missing=0

  for dep in "$@"; do
    if ! is_satisfied "$dep"; then
      printf '%s\n' "$dep"
      missing=1
    fi
  done

  (( missing == 0 )) && exit 0
  exit 127
fi

if [[ ${1:-} == "-Q" ]]; then
  shift
  is_satisfied "${1:-}" && exit 0
  exit 1
fi

exit 2
PACMAN

cat > "$tmp/bin/sudo" <<'SUDO'
#!/bin/bash

packages=()
for arg in "$@"; do
  case "$arg" in
    pacman|-S|--noconfirm|--needed)
      ;;
    *)
      packages+=("$arg")
      ;;
  esac
done

printf '%s\n' "${packages[@]}" >> "$RYOKU_TEST_REQUESTED"

if printf '%s\n' "${packages[@]}" | grep -Fx quickshell >/dev/null; then
  echo "sudo pacman should not be asked to install quickshell" >&2
  exit 9
fi

printf '%s\n' "${packages[@]}" >> "$RYOKU_TEST_INSTALLED"
SUDO

chmod 755 "$tmp/bin/pacman" "$tmp/bin/sudo"

RYOKU_INSTALL="$tmp/install" \
RYOKU_TEST_INSTALLED="$tmp/installed" \
RYOKU_TEST_REQUESTED="$tmp/requested" \
PATH="$tmp/bin:$ROOT_DIR/bin:$PATH" \
  bash "$ROOT_DIR/install/packaging/aur-core.sh"

[[ -f $tmp/requested ]] || fail "aur-core should request missing packages from the offline pacman mirror"

if grep -Fx quickshell "$tmp/requested" >/dev/null; then
  fail "aur-core should not request packages already satisfied by providers"
fi

grep -Fx gradia "$tmp/requested" >/dev/null || fail "aur-core should request missing package gradia"
grep -Fx tofi "$tmp/requested" >/dev/null || fail "aur-core should request missing package tofi"

echo "PASS: ryoku AUR core provider-aware install filtering"
