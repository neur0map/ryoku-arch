#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  grep -Fq "$needle" <<<"$haystack" || fail "$message"
}

assert_file_contains() {
  local file="$1"
  local needle="$2"
  local message="$3"

  grep -Fq "$needle" "$file" || fail "$message"
}

assert_package_listed() {
  local package="$1"

  grep -qxF "$package" "$ROOT_DIR/install/ryoku-other.packages" \
    || fail "install/ryoku-other.packages should include $package for offline doctor repair"
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin" "$tmp/user/.config/niri/config.d" "$tmp/user/.config/environment.d" "$tmp/fake-ryoku"

cat >"$tmp/user/.config/niri/config.d/40-environment.kdl" <<'NIRI'
environment {
    QT_QPA_PLATFORM "wayland"
}
NIRI

cat >"$tmp/user/.config/environment.d/ryoku.conf" <<'SYSTEMD'
QT_QPA_PLATFORM=wayland
SYSTEMD

cat >"$tmp/bin/pacman" <<'PACMAN'
#!/bin/bash

case "${1:-}" in
  -T)
    shift
    printf '%s\n' "$@"
    ;;
  -Q)
    exit 1
    ;;
esac
PACMAN

cat >"$tmp/bin/lspci" <<'LSPCI'
#!/bin/bash

cat "$RYOKU_TEST_LSPCI"
LSPCI

cat >"$tmp/bin/systemctl" <<'SYSTEMCTL'
#!/bin/bash

exit 0
SYSTEMCTL

cat >"$tmp/bin/dbus-update-activation-environment" <<'DBUS'
#!/bin/bash

exit 0
DBUS

cat >"$tmp/bin/ryoku-pkg-add" <<'PKGADD'
#!/bin/bash

printf '%s\n' "$*" >> "$RYOKU_TEST_PKG_ADD_LOG"
PKGADD

cat >"$tmp/bin/clinfo" <<'CLINFO'
#!/bin/bash

exit 1
CLINFO

chmod 755 "$tmp/bin/pacman" "$tmp/bin/lspci" "$tmp/bin/systemctl" "$tmp/bin/dbus-update-activation-environment" "$tmp/bin/ryoku-pkg-add" "$tmp/bin/clinfo"

cat >"$tmp/amd-lspci" <<'LSPCI'
03:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Navi 31 [Radeon RX 7900 XTX]
LSPCI

output=$(
  HOME="$tmp/user" \
  XDG_CONFIG_HOME="$tmp/user/.config" \
  RYOKU_PATH="$tmp/fake-ryoku" \
  RYOKU_DOCTOR_ASSUME_NO=1 \
  RYOKU_TEST_LSPCI="$tmp/amd-lspci" \
  PATH="$tmp/bin:$PATH" \
    "$ROOT_DIR/bin/ryoku-doctor" apps 2>&1 || true
)

assert_contains "$output" "Ryoku Doctor: apps" "apps doctor should have its own command"
assert_contains "$output" "Fixed Qt app platform fallback: wayland;xcb" "apps doctor should repair strict Qt Wayland settings"
assert_contains "$output" "Detected GPUs: AMD" "apps doctor should detect AMD GPUs generically"
assert_contains "$output" "OpenCL GPU runtime is missing." "apps doctor should diagnose missing GPU compute runtime"
assert_contains "$output" "Run: ryoku-pkg-add rocm-opencl-runtime clinfo" "apps doctor should suggest the AMD OpenCL runtime"
assert_file_contains "$tmp/user/.config/niri/config.d/40-environment.kdl" 'QT_QPA_PLATFORM "wayland;xcb"' \
  "apps doctor should update the user's niri Qt platform fallback"
assert_file_contains "$tmp/user/.config/environment.d/ryoku.conf" 'QT_QPA_PLATFORM=wayland;xcb' \
  "apps doctor should update the user's systemd Qt platform fallback"

cat >"$tmp/nvidia-lspci" <<'LSPCI'
01:00.0 VGA compatible controller: NVIDIA Corporation AD104 [GeForce RTX 4070 SUPER]
LSPCI

output=$(
  HOME="$tmp/user" \
  XDG_CONFIG_HOME="$tmp/user/.config" \
  RYOKU_PATH="$tmp/fake-ryoku" \
  RYOKU_DOCTOR_ASSUME_NO=1 \
  RYOKU_TEST_LSPCI="$tmp/nvidia-lspci" \
  PATH="$tmp/bin:$PATH" \
    "$ROOT_DIR/bin/ryoku-doctor" apps 2>&1 || true
)

assert_contains "$output" "Detected GPUs: NVIDIA" "apps doctor should detect NVIDIA GPUs generically"
assert_contains "$output" "Run: ryoku-pkg-add opencl-nvidia clinfo" "apps doctor should suggest the NVIDIA OpenCL runtime"

cat >"$tmp/intel-lspci" <<'LSPCI'
00:02.0 VGA compatible controller: Intel Corporation Meteor Lake-P [Intel Arc Graphics]
LSPCI

output=$(
  HOME="$tmp/user" \
  XDG_CONFIG_HOME="$tmp/user/.config" \
  RYOKU_PATH="$tmp/fake-ryoku" \
  RYOKU_DOCTOR_ASSUME_NO=1 \
  RYOKU_TEST_LSPCI="$tmp/intel-lspci" \
  PATH="$tmp/bin:$PATH" \
    "$ROOT_DIR/bin/ryoku-doctor" apps 2>&1 || true
)

assert_contains "$output" "Detected GPUs: Intel" "apps doctor should detect Intel GPUs generically"
assert_contains "$output" "Run: ryoku-pkg-add intel-compute-runtime clinfo" "apps doctor should suggest the Intel OpenCL runtime"

cat >"$tmp/bin/clinfo" <<'CLINFO'
#!/bin/bash

cat <<'INFO'
Number of platforms                               1
Device Type                                      GPU
INFO
CLINFO

chmod 755 "$tmp/bin/clinfo"

output=$(
  HOME="$tmp/user" \
  XDG_CONFIG_HOME="$tmp/user/.config" \
  RYOKU_PATH="$tmp/fake-ryoku" \
  RYOKU_TEST_LSPCI="$tmp/amd-lspci" \
  PATH="$tmp/bin:$PATH" \
    "$ROOT_DIR/bin/ryoku-doctor" apps 2>&1
) || fail "apps doctor should pass when OpenCL is available: $output"

assert_contains "$output" "OpenCL GPU runtime OK." "apps doctor should not suggest packages when clinfo sees a GPU"

cat >"$tmp/bin/clinfo" <<'CLINFO'
#!/bin/bash

exit 1
CLINFO
chmod 755 "$tmp/bin/clinfo"
>"$tmp/pkg-add.log"

output=$(
  HOME="$tmp/user" \
  XDG_CONFIG_HOME="$tmp/user/.config" \
  RYOKU_PATH="$tmp/fake-ryoku" \
  RYOKU_DOCTOR_ASSUME_YES=1 \
  RYOKU_TEST_LSPCI="$tmp/amd-lspci" \
  RYOKU_TEST_PKG_ADD_LOG="$tmp/pkg-add.log" \
  PATH="$tmp/bin:$PATH" \
    "$ROOT_DIR/bin/ryoku-doctor" apps 2>&1
) || fail "apps doctor should install missing app compatibility packages with confirmation: $output"

assert_contains "$output" "Install missing app compatibility packages now? [Y/n] y" \
  "apps doctor should show the confirmation decision"
assert_file_contains "$tmp/pkg-add.log" "rocm-opencl-runtime clinfo" \
  "apps doctor should install generic AMD OpenCL support through ryoku-pkg-add"

assert_package_listed clinfo
assert_package_listed rocm-opencl-runtime
assert_package_listed opencl-nvidia
assert_package_listed intel-compute-runtime

echo "PASS: ryoku-doctor apps repairs generic app compatibility issues"
