#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"

  [[ -f $path ]] || fail "$path should exist"
}

assert_executable() {
  local path="$1"

  assert_file "$path"
  [[ -x $path ]] || fail "$path should be executable"
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq -- "$pattern" "$file" || fail "$message"
}

assert_package_present() {
  local file="$1"
  local package="$2"

  grep -qxF "$package" "$file" || fail "$file should include package: $package"
}

for helper in \
  bin/ryoku-hw-asus-expertbook-b9406 \
  bin/ryoku-hw-asus-zenbook-ux5406aa \
  bin/ryoku-hw-nvidia-gsp \
  bin/ryoku-hw-nvidia-without-gsp; do
  assert_executable "$helper"
done

for script in \
  install/config/hardware/intel/fred.sh \
  install/config/hardware/intel/sof-firmware.sh \
  install/config/hardware/asus/fix-asus-ptl-display-backlight.sh \
  install/config/hardware/asus/fix-asus-ptl-b9406-display.sh \
  install/config/hardware/asus/fix-asus-ptl-b9406-touchpad.sh \
  install/config/hardware/asus/fix-z13-touchpad.sh \
  install/config/hardware/lenovo/fix-yoga-pro7-bass-speakers.sh; do
  assert_file "$script"
  assert_contains install/config/all.sh "${script#install/}" "install/config/all.sh should run $script"
done

assert_file default/wireplumber/wireplumber.conf.d/bluetooth-a2dp-autoconnect.conf
assert_contains install/config/hardware/bluetooth.sh 'bluetooth-a2dp-autoconnect\.conf' \
  "Bluetooth setup should copy the WirePlumber A2DP auto-connect rule"

assert_contains install/config/hardware/intel/video-acceleration.sh 'panther\\ lake' \
  "Intel video acceleration should recognize Panther Lake GPUs"
assert_contains install/config/hardware/intel/ptl-kernel.sh 'ryoku-hw-match "XPS"' \
  "PTL kernel should be scoped to Dell XPS Panther Lake systems"
assert_contains install/config/hardware/intel/sof-firmware.sh 'ryoku-hw-intel-ptl' \
  "non-XPS Panther Lake systems should install sof-firmware instead of linux-ptl"
assert_package_present install/ryoku-other.packages sof-firmware

assert_contains install/config/hardware/nvidia.sh 'ryoku-hw-nvidia-gsp' \
  "NVIDIA setup should use the Ryoku GSP helper"
assert_contains install/config/hardware/nvidia.sh 'ryoku-hw-nvidia-without-gsp' \
  "NVIDIA setup should use the Ryoku non-GSP helper"
assert_contains bin/ryoku-hw-hybrid-gpu 'ryoku-cmd-present supergfxctl' \
  "Hybrid GPU detection should prefer supergfxctl when available"
assert_contains bin/ryoku-hw-hybrid-gpu 'supergfxctl -s' \
  "Hybrid GPU detection should inspect the active supergfxd mode"

tmp_dir=$(mktemp -d)
mkdir -p "$tmp_dir/ryoku/bin" "$tmp_dir/bin"

cat >"$tmp_dir/ryoku/bin/ryoku-cmd-present" <<'EOF'
#!/bin/bash
if [[ ${RYOKU_TEST_SUPERGFX_PRESENT:-0} == "1" && ${1:-} == "supergfxctl" ]]; then
  exit 0
fi
exit 1
EOF

cat >"$tmp_dir/bin/supergfxctl" <<'EOF'
#!/bin/bash
printf '%s\n' "${RYOKU_TEST_SUPERGFX_MODE:-Integrated}"
EOF

cat >"$tmp_dir/bin/lspci" <<'EOF'
#!/bin/bash
cat <<'LSPCI'
00:02.0 VGA compatible controller: Intel Corporation Device
01:00.0 3D controller: NVIDIA Corporation Device
LSPCI
EOF

chmod 755 "$tmp_dir/ryoku/bin/ryoku-cmd-present" "$tmp_dir/bin/supergfxctl" "$tmp_dir/bin/lspci"

RYOKU_PATH="$tmp_dir/ryoku" \
RYOKU_TEST_SUPERGFX_PRESENT=1 \
RYOKU_TEST_SUPERGFX_MODE=Hybrid \
PATH="$tmp_dir/bin:$PATH" \
  "$ROOT_DIR/bin/ryoku-hw-hybrid-gpu" || \
  fail "Hybrid GPU detection should return true when supergfxctl reports Hybrid"

if RYOKU_PATH="$tmp_dir/ryoku" \
    RYOKU_TEST_SUPERGFX_PRESENT=1 \
    RYOKU_TEST_SUPERGFX_MODE=Integrated \
    PATH="$tmp_dir/bin:$PATH" \
      "$ROOT_DIR/bin/ryoku-hw-hybrid-gpu"; then
  fail "Hybrid GPU detection should return false when supergfxctl reports Integrated"
fi

RYOKU_PATH="$tmp_dir/ryoku" \
RYOKU_TEST_SUPERGFX_PRESENT=0 \
PATH="$tmp_dir/bin:$PATH" \
  "$ROOT_DIR/bin/ryoku-hw-hybrid-gpu" || \
  fail "Hybrid GPU detection should fall back to PCI display device count"

if grep -RIl 'omarchy' \
    bin/ryoku-hw-asus-expertbook-b9406 \
    bin/ryoku-hw-asus-zenbook-ux5406aa \
    bin/ryoku-hw-nvidia-gsp \
    bin/ryoku-hw-nvidia-without-gsp \
    install/config/hardware/intel/fred.sh \
    install/config/hardware/intel/sof-firmware.sh \
    install/config/hardware/asus/fix-asus-ptl-display-backlight.sh \
    install/config/hardware/asus/fix-asus-ptl-b9406-display.sh \
    install/config/hardware/asus/fix-asus-ptl-b9406-touchpad.sh \
    install/config/hardware/asus/fix-z13-touchpad.sh \
    install/config/hardware/lenovo/fix-yoga-pro7-bass-speakers.sh \
    default/wireplumber/wireplumber.conf.d/bluetooth-a2dp-autoconnect.conf >/dev/null; then
  fail "new upstreamed hardware files should not contain Omarchy names"
fi

bash -n \
  bin/ryoku-hw-asus-expertbook-b9406 \
  bin/ryoku-hw-asus-zenbook-ux5406aa \
  bin/ryoku-hw-nvidia-gsp \
  bin/ryoku-hw-nvidia-without-gsp \
  install/config/hardware/intel/fred.sh \
  install/config/hardware/intel/sof-firmware.sh \
  install/config/hardware/asus/fix-asus-ptl-display-backlight.sh \
  install/config/hardware/asus/fix-asus-ptl-b9406-display.sh \
  install/config/hardware/asus/fix-asus-ptl-b9406-touchpad.sh \
  install/config/hardware/asus/fix-z13-touchpad.sh \
  install/config/hardware/lenovo/fix-yoga-pro7-bass-speakers.sh \
  install/config/hardware/bluetooth.sh \
  install/config/hardware/nvidia.sh

echo "PASS: Ryoku upstream hardware core parity"
