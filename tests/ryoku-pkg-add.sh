#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin"
: > "$tmp/installed"

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

printf '%s\n' "${packages[@]}" > "$RYOKU_TEST_REQUESTED"

if printf '%s\n' "${packages[@]}" | grep -Fx quickshell >/dev/null; then
  echo "sudo pacman should not be asked to install quickshell" >&2
  exit 9
fi

printf '%s\n' "${packages[@]}" >> "$RYOKU_TEST_INSTALLED"
SUDO

cat > "$tmp/bin/yay" <<'YAY'
#!/bin/bash

packages=()
for arg in "$@"; do
  case "$arg" in
    -S|--noconfirm|--needed)
      ;;
    *)
      packages+=("$arg")
      ;;
  esac
done

printf '%s\n' "${packages[@]}" > "$RYOKU_TEST_AUR_REQUESTED"

if printf '%s\n' "${packages[@]}" | grep -Fx quickshell >/dev/null; then
  echo "yay should not be asked to install quickshell" >&2
  exit 9
fi

printf '%s\n' "${packages[@]}" >> "$RYOKU_TEST_INSTALLED"
YAY

chmod 755 "$tmp/bin/pacman" "$tmp/bin/sudo" "$tmp/bin/yay"

if RYOKU_TEST_INSTALLED="$tmp/installed" \
  PATH="$tmp/bin:$ROOT_DIR/bin:$PATH" \
  ryoku-pkg-missing quickshell; then
  fail "ryoku-pkg-missing should treat provided packages as satisfied"
fi

RYOKU_TEST_INSTALLED="$tmp/installed" \
RYOKU_TEST_REQUESTED="$tmp/requested" \
PATH="$tmp/bin:$ROOT_DIR/bin:$PATH" \
  "$ROOT_DIR/bin/ryoku-pkg-add" bash quickshell jq

[[ -f $tmp/requested ]] || fail "ryoku-pkg-add should request missing packages"

if grep -Fx quickshell "$tmp/requested" >/dev/null; then
  fail "ryoku-pkg-add should not request packages already satisfied by providers"
fi

grep -Fx bash "$tmp/requested" >/dev/null || fail "ryoku-pkg-add should request missing package bash"
grep -Fx jq "$tmp/requested" >/dev/null || fail "ryoku-pkg-add should request missing package jq"

if RYOKU_TEST_INSTALLED="$tmp/installed" \
  PATH="$tmp/bin:$ROOT_DIR/bin:$PATH" \
  ryoku-pkg-missing bash quickshell jq; then
  fail "ryoku-pkg-missing should return false after dependencies are installed or provided"
fi

: > "$tmp/installed"

RYOKU_TEST_INSTALLED="$tmp/installed" \
RYOKU_TEST_AUR_REQUESTED="$tmp/aur-requested" \
PATH="$tmp/bin:$ROOT_DIR/bin:$PATH" \
  "$ROOT_DIR/bin/ryoku-pkg-aur-add" tofi quickshell gradia

[[ -f $tmp/aur-requested ]] || fail "ryoku-pkg-aur-add should request missing packages"

if grep -Fx quickshell "$tmp/aur-requested" >/dev/null; then
  fail "ryoku-pkg-aur-add should not request packages already satisfied by providers"
fi

grep -Fx tofi "$tmp/aur-requested" >/dev/null || fail "ryoku-pkg-aur-add should request missing package tofi"
grep -Fx gradia "$tmp/aur-requested" >/dev/null || fail "ryoku-pkg-aur-add should request missing package gradia"

echo "PASS: ryoku package helpers provider-aware install filtering"
