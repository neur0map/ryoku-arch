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
