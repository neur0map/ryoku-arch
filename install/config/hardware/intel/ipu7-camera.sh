# Install MIPI camera support for Intel IPU7 hardware. The AUR package is
# intel-ipu7-camera-bin; Ryoku skips it during offline ISO installs until the
# full AUR dependency chain is bundled in the offline mirror.

if grep -q "OVTI08F4" /sys/bus/acpi/devices/*/hid 2>/dev/null; then
  if [[ -n ${RYOKU_CHROOT_INSTALL:-} && -z ${RYOKU_ONLINE_INSTALL:-} ]]; then
    echo "Ryoku ISO does not bundle the Intel IPU7 camera AUR stack yet; skipping camera extras for offline install."
    exit 0
  fi

  if ! ryoku-pkg-aur-add intel-ipu7-camera-bin; then
    echo "Intel IPU7 camera package is unavailable; skipping camera extras."
    exit 0
  fi
fi
