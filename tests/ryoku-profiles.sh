#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_not_default_package() {
  local package="$1"

  if grep -qxF "$package" "$ROOT_DIR/install/ryoku-base.packages" ||
     grep -qxF "$package" "$ROOT_DIR/install/ryoku-aur.packages"; then
    fail "$package should stay out of the default install manifests"
  fi
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin"
: >"$tmp/installed"

cat >"$tmp/bin/pacman" <<'PACMAN'
#!/bin/bash

is_satisfied() {
  local dep="$1"

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

cat >"$tmp/bin/sudo" <<'SUDO'
#!/bin/bash

if [[ ${1:-} == "pacman" ]]; then
  shift
fi

packages=()
for arg in "$@"; do
  case "$arg" in
    -S|--noconfirm|--needed)
      ;;
    heroic-games-launcher-bin|protonup-qt-bin|bottles)
      exit 1
      ;;
    *)
      packages+=("$arg")
      ;;
  esac
done

printf '%s\n' "${packages[@]}" >>"$RYOKU_TEST_PACMAN_REQUESTED"
printf '%s\n' "${packages[@]}" >>"$RYOKU_TEST_INSTALLED"
SUDO

cat >"$tmp/bin/yay" <<'YAY'
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

printf '%s\n' "${packages[@]}" >>"$RYOKU_TEST_AUR_REQUESTED"
printf '%s\n' "${packages[@]}" >>"$RYOKU_TEST_INSTALLED"
YAY

cat >"$tmp/bin/lspci" <<'LSPCI'
#!/bin/bash
exit 0
LSPCI

chmod 755 "$tmp/bin/pacman" "$tmp/bin/sudo" "$tmp/bin/yay" "$tmp/bin/lspci"

for package in steam steam-devices gamescope mangohud lutris heroic-games-launcher-bin protonup-qt-bin bottles; do
  assert_not_default_package "$package"
done

json="$(
  RYOKU_TEST_INSTALLED="$tmp/installed" \
  PATH="$tmp/bin:$ROOT_DIR/bin:$PATH" \
    "$ROOT_DIR/bin/ryoku-cmd-profile-list" --json
)"

[[ $json == *'"id":"gaming"'* ]] || fail "profile list should expose the Gaming profile"
[[ $json == *'"installed":false'* ]] || fail "Gaming should report not installed before package install"
[[ $json == *'"packageCount":21'* ]] || fail "Gaming should report the full install package count"
[[ $json == *'"packages":["steam","steam-devices","gamemode"'* ]] || fail "Gaming should expose official package details"
[[ $json == *'"aurPackages":["heroic-games-launcher-bin","protonup-qt-bin","bottles"]'* ]] || fail "Gaming should expose AUR package details"
[[ $json == *'"hardwarePackages":["lib32-vulkan-radeon","lib32-vulkan-intel","lib32-nvidia-utils","lib32-nvidia-580xx-utils"]'* ]] || fail "Gaming should expose hardware add-on package details"

RYOKU_TEST_INSTALLED="$tmp/installed" \
RYOKU_TEST_PACMAN_REQUESTED="$tmp/pacman-requested" \
RYOKU_TEST_AUR_REQUESTED="$tmp/aur-requested" \
RYOKU_PROFILE_STATE_DIR="$tmp/state" \
PATH="$tmp/bin:$ROOT_DIR/bin:$PATH" \
  "$ROOT_DIR/bin/ryoku-install-profile" gaming

grep -Fx steam "$tmp/pacman-requested" >/dev/null || fail "Gaming should install Steam"
grep -Fx gamescope "$tmp/pacman-requested" >/dev/null || fail "Gaming should install Gamescope"
grep -Fx heroic-games-launcher-bin "$tmp/aur-requested" >/dev/null || fail "Gaming should install Heroic"
grep -Fx protonup-qt-bin "$tmp/aur-requested" >/dev/null || fail "Gaming should install ProtonUp-Qt"
grep -Fx bottles "$tmp/aur-requested" >/dev/null || fail "Gaming should install Bottles"

status="$(
  RYOKU_TEST_INSTALLED="$tmp/installed" \
  RYOKU_PROFILE_STATE_DIR="$tmp/state" \
  PATH="$tmp/bin:$ROOT_DIR/bin:$PATH" \
    "$ROOT_DIR/bin/ryoku-cmd-profile-status" --json gaming
)"

[[ $status == *'"installed":true'* ]] || fail "Gaming should report installed after package install"
[[ -f $tmp/state/gaming.state ]] || fail "Gaming should write profile state"

echo "PASS: ryoku profile installer"
