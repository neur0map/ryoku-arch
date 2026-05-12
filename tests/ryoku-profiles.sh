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

if [[ ${1:-} == "-Sl" && ${2:-} == "blackarch" ]]; then
  [[ -f $RYOKU_TEST_BLACKARCH_ENABLED ]] && exit 0
  exit 1
fi

if [[ ${1:-} == "-Sy" ]]; then
  exit 0
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

if [[ ${1:-} == "pacman" && ${2:-} == "-Sy" ]]; then
  "$@"
  exit $?
fi

if [[ ${1:-} == "pacman" ]]; then
  shift
fi

if [[ -x ${1:-} ]]; then
  "$@"
  exit $?
fi

packages=()
for arg in "$@"; do
  case "$arg" in
    -S|--noconfirm|--needed)
      ;;
    heroic-games-launcher-bin|protonup-qt-bin|bottles|katana|neo4j-community|python-bloodhound)
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

cat >"$tmp/bin/curl" <<'CURL'
#!/bin/bash

out=""
while (( $# > 0 )); do
  case "$1" in
    -o)
      out="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

[[ -n $out ]] || exit 2
cat >"$out" <<'STRAP'
#!/bin/bash
touch "$RYOKU_TEST_BLACKARCH_ENABLED"
STRAP
CURL

cat >"$tmp/bin/sha1sum" <<'SHA1'
#!/bin/bash

if [[ ${1:-} == "-c" ]]; then
  cat >/dev/null
  exit 0
fi

command sha1sum "$@"
SHA1

cat >"$tmp/bin/lspci" <<'LSPCI'
#!/bin/bash
exit 0
LSPCI

chmod 755 "$tmp/bin/pacman" "$tmp/bin/sudo" "$tmp/bin/yay" "$tmp/bin/curl" "$tmp/bin/sha1sum" "$tmp/bin/lspci"

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
[[ $json == *'"id":"secpulse-basic"'* ]] || fail "profile list should expose SecPulse Basic"
[[ $json == *'"id":"secpulse-advanced"'* ]] || fail "profile list should expose SecPulse Advanced"
[[ $json == *'"name":"SecPulse Basic"'*'"packageCount":35'* ]] || fail "SecPulse Basic should report all named packages"
[[ $json == *'"name":"SecPulse Advanced"'*'"packageCount":84'* ]] || fail "SecPulse Advanced should report all named packages"
[[ $json == *'"blackarchPackages":["seclists","feroxbuster","nuclei","burpsuite"'* ]] || fail "SecPulse profiles should expose BlackArch package details"
[[ $json == *'"blackarchPackages":["seclists","feroxbuster","nuclei","burpsuite","wfuzz","ffuf","dirsearch","enum4linux","whatweb","commix"'* ]] || fail "SecPulse Advanced should expose advanced BlackArch package details"

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

RYOKU_TEST_INSTALLED="$tmp/installed" \
RYOKU_TEST_PACMAN_REQUESTED="$tmp/pacman-requested" \
RYOKU_TEST_AUR_REQUESTED="$tmp/aur-requested" \
RYOKU_TEST_BLACKARCH_ENABLED="$tmp/blackarch-enabled" \
RYOKU_PROFILE_STATE_DIR="$tmp/state" \
PATH="$tmp/bin:$ROOT_DIR/bin:$PATH" \
  "$ROOT_DIR/bin/ryoku-install-profile" secpulse-basic

[[ -f $tmp/blackarch-enabled ]] || fail "SecPulse Basic should bootstrap the BlackArch repo for BlackArch packages"
grep -Fx seclists "$tmp/pacman-requested" >/dev/null || fail "SecPulse Basic should install named BlackArch packages through pacman"
grep -Fx katana "$tmp/aur-requested" >/dev/null || fail "SecPulse Basic should install AUR-only tools through yay"

status="$(
  RYOKU_TEST_INSTALLED="$tmp/installed" \
  RYOKU_PROFILE_STATE_DIR="$tmp/state" \
  PATH="$tmp/bin:$ROOT_DIR/bin:$PATH" \
    "$ROOT_DIR/bin/ryoku-cmd-profile-status" --json gaming
)"

[[ $status == *'"installed":true'* ]] || fail "Gaming should report installed after package install"
[[ -f $tmp/state/gaming.state ]] || fail "Gaming should write profile state"

echo "PASS: ryoku profile installer"
