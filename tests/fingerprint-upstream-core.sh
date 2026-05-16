#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq -- "$pattern" "$file" || fail "$message"
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if grep -Eq -- "$pattern" "$file"; then
    fail "$message"
  fi
}

run_with_stubs() {
  local tmp_dir="$1"
  local mode="${2:-}"

  mkdir -p "$tmp_dir/bin" "$tmp_dir/pam"
  printf 'auth required pam_unix.so\n' >"$tmp_dir/pam/sudo"
  printf 'auth required pam_unix.so\n' >"$tmp_dir/pam/polkit-1"
  if [[ $mode == "--remove" ]]; then
    sed -i '1i auth    sufficient pam_fprintd.so' "$tmp_dir/pam/sudo"
    sed -i '1i auth      sufficient pam_fprintd.so' "$tmp_dir/pam/polkit-1"
  fi
  : >"$tmp_dir/events"

  cat >"$tmp_dir/bin/sudo" <<'EOF'
#!/bin/bash
printf 'sudo:%s\n' "$*" >>"$RYOKU_TEST_EVENTS"
if [[ ${1:-} == "pacman" ]]; then
  exit 0
fi
exec "$@"
EOF

  cat >"$tmp_dir/bin/ryoku-pkg-present" <<'EOF'
#!/bin/bash
printf 'pkg-present:%s\n' "$*" >>"$RYOKU_TEST_EVENTS"
[[ ${1:-} == "libfprint" ]]
EOF

  cat >"$tmp_dir/bin/ryoku-pkg-aur-add" <<'EOF'
#!/bin/bash
printf 'pkg-aur-add:%s\n' "$*" >>"$RYOKU_TEST_EVENTS"
exit 0
EOF

  cat >"$tmp_dir/bin/ryoku-pkg-add" <<'EOF'
#!/bin/bash
printf 'pkg-add:%s\n' "$*" >>"$RYOKU_TEST_EVENTS"
exit 0
EOF

  cat >"$tmp_dir/bin/ryoku-pkg-drop" <<'EOF'
#!/bin/bash
printf 'pkg-drop:%s\n' "$*" >>"$RYOKU_TEST_EVENTS"
exit 0
EOF

  cat >"$tmp_dir/bin/fprintd-list" <<'EOF'
#!/bin/bash
printf 'Device at /net/reactivated/Fprint/Device/0\n'
EOF

  cat >"$tmp_dir/bin/fprintd-enroll" <<'EOF'
#!/bin/bash
printf 'enroll:%s\n' "$*" >>"$RYOKU_TEST_EVENTS"
exit 0
EOF

  cat >"$tmp_dir/bin/fprintd-verify" <<'EOF'
#!/bin/bash
printf 'verify\n' >>"$RYOKU_TEST_EVENTS"
exit 0
EOF

  chmod 755 "$tmp_dir/bin"/*

  local command=("$ROOT_DIR/bin/ryoku-setup-fingerprint")
  [[ -z $mode ]] || command+=("$mode")

  RYOKU_TEST_EVENTS="$tmp_dir/events" \
  RYOKU_PAM_SUDO_FILE="$tmp_dir/pam/sudo" \
  RYOKU_PAM_POLKIT_FILE="$tmp_dir/pam/polkit-1" \
  PATH="$tmp_dir/bin:$PATH" \
    "${command[@]}" >/dev/null
}

install_tmp=$(mktemp -d)
run_with_stubs "$install_tmp"

mapfile -t install_events <"$install_tmp/events"

[[ ${install_events[0]:-} == "pkg-present:libfprint" ]] || \
  fail "setup should check for stock libfprint first"
[[ ${install_events[1]:-} == "sudo:pacman -Rdd --noconfirm libfprint" ]] || \
  fail "setup should pre-remove libfprint without dependency checks"
[[ ${install_events[2]:-} == "pkg-aur-add:libfprint-git" ]] || \
  fail "setup should install libfprint-git through the AUR helper"
[[ ${install_events[3]:-} == "pkg-add:fprintd usbutils" ]] || \
  fail "setup should install official fingerprint packages after libfprint-git"

grep -q 'pam_fprintd\.so' "$install_tmp/pam/sudo" || \
  fail "setup should add fingerprint PAM config to sudo"
grep -q 'pam_fprintd\.so' "$install_tmp/pam/polkit-1" || \
  fail "setup should add fingerprint PAM config to polkit"

remove_tmp=$(mktemp -d)
run_with_stubs "$remove_tmp" "--remove"

grep -qx 'pkg-drop:fprintd libfprint-git' "$remove_tmp/events" || \
  fail "remove should use ryoku-pkg-drop for fprintd and libfprint-git"
grep -q 'pam_fprintd\.so' "$remove_tmp/pam/sudo" && \
  fail "remove should delete fingerprint PAM config from sudo"
grep -q 'pam_fprintd\.so' "$remove_tmp/pam/polkit-1" && \
  fail "remove should delete fingerprint PAM config from polkit"

assert_contains bin/ryoku-setup-fingerprint 'ryoku-pkg-aur-add libfprint-git' \
  "fingerprint setup should use libfprint-git for newer sensors"
assert_contains bin/ryoku-setup-fingerprint 'pacman -Rdd --noconfirm libfprint' \
  "fingerprint setup should avoid the libfprint conflict prompt"
assert_contains bin/ryoku-setup-fingerprint 'ryoku-pkg-drop fprintd libfprint-git' \
  "fingerprint removal should go through Ryoku package helpers"
assert_not_contains bin/ryoku-setup-fingerprint 'hyprlock|\.config/hypr' \
  "fingerprint upstreaming should not add Hyprland lockscreen coupling"

bash -n bin/ryoku-setup-fingerprint tests/fingerprint-upstream-core.sh

echo "PASS: fingerprint upstream core parity"
