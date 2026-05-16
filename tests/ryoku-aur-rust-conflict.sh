#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

grep -qxF rust "$ROOT_DIR/install/ryoku-base.packages" || \
  fail "Ryoku ISO/base defaults should ship Arch rust"
! grep -qxF rustup "$ROOT_DIR/install/ryoku-base.packages" || \
  fail "Ryoku base defaults should not force rustup over Arch rust"
grep -qxF localsend-bin "$ROOT_DIR/install/ryoku-aur.packages" || \
  fail "Ryoku should install LocalSend from localsend-bin to avoid rustup make-dep conflicts"
! grep -qxF localsend "$ROOT_DIR/install/ryoku-aur.packages" || \
  fail "Ryoku should not install source localsend by default because it pulls rustup during AUR updates"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin" "$tmp/home"

cat >"$tmp/bin/pacman" <<'PACMAN'
#!/bin/bash

case "${1:-}" in
  -Q)
    case "${2:-}" in
      localsend)
        exit 0
        ;;
      localsend-bin)
        exit 1
        ;;
      *)
        exit 1
        ;;
    esac
    ;;
  -Qem)
    printf '%s\n' "localsend 1.17.0-3"
    ;;
  *)
    printf 'unexpected pacman args: %s\n' "$*" >&2
    exit 2
    ;;
esac
PACMAN

cat >"$tmp/bin/sudo" <<'SUDO'
#!/bin/bash
printf 'sudo:%s\n' "$*" >>"$RYOKU_TEST_AUR_LOG"
if [[ $* == "pacman -Rdd --noconfirm localsend" ]]; then
  exit 0
fi
exit 2
SUDO

cat >"$tmp/bin/yay" <<'YAY'
#!/bin/bash
printf 'yay:%s\n' "$*" >>"$RYOKU_TEST_AUR_LOG"
case "$*" in
  "-S --noconfirm --needed localsend-bin")
    exit 0
    ;;
  "-Sua --noconfirm --cleanafter --ignore gcc14,gcc14-libs")
    exit 0
    ;;
  *)
    exit 2
    ;;
esac
YAY

cat >"$tmp/bin/curl" <<'CURL'
#!/bin/bash
exit 0
CURL

chmod +x "$tmp/bin/pacman" "$tmp/bin/sudo" "$tmp/bin/yay" "$tmp/bin/curl"

HOME="$tmp/home" \
RYOKU_PATH="$ROOT_DIR" \
RYOKU_TEST_AUR_LOG="$tmp/aur.log" \
PATH="$tmp/bin:$ROOT_DIR/bin:$PATH" \
  bash "$ROOT_DIR/bin/ryoku-update-aur-pkgs"

mapfile -t events <"$tmp/aur.log"
[[ ${events[0]:-} == "sudo:pacman -Rdd --noconfirm localsend" ]] || \
  fail "updater should remove source localsend before installing localsend-bin"
[[ ${events[1]:-} == "yay:-S --noconfirm --needed localsend-bin" ]] || \
  fail "updater should install localsend-bin before AUR updates"
[[ ${events[2]:-} == "yay:-Sua --noconfirm --cleanafter --ignore gcc14,gcc14-libs" ]] || \
  fail "updater should run AUR updates after the LocalSend transition"

rm -f "$tmp/aur.log"
cat >"$tmp/bin/sudo" <<'SUDO'
#!/bin/bash
printf 'sudo:%s\n' "$*" >>"$RYOKU_TEST_AUR_LOG"
if [[ $* == "pacman -Rdd --noconfirm localsend" ]]; then
  exit 1
fi
exit 2
SUDO
chmod +x "$tmp/bin/sudo"

set +e
failure_output=$(
  HOME="$tmp/home" \
  RYOKU_PATH="$ROOT_DIR" \
  RYOKU_TEST_AUR_LOG="$tmp/aur.log" \
  PATH="$tmp/bin:$ROOT_DIR/bin:$PATH" \
    bash "$ROOT_DIR/bin/ryoku-update-aur-pkgs" 2>&1
)
failure_status=$?
set -e

(( failure_status == 0 )) || fail "LocalSend transition failure should not abort updater"
[[ $failure_output == *"skipping AUR package upgrades"* ]] || \
  fail "LocalSend transition failure should say only AUR package upgrades are skipped"
if [[ -f $tmp/aur.log ]] && grep -F -- "-Sua --noconfirm" "$tmp/aur.log" >/dev/null; then
  fail "LocalSend transition failure should skip yay AUR upgrades"
fi

echo "PASS: Ryoku AUR Rust conflict handling"
