# Install MIPI camera support for Intel IPU7 hardware. The AUR
# package is intel-ipu7-camera-bin; omarchy ships a custom-named
# intel-ipu7-camera in their hosted repo, but Ryoku consumes the
# upstream AUR PKGBUILD directly via the boot overlay.

if grep -q "OVTI08F4" /sys/bus/acpi/devices/*/hid 2>/dev/null; then
  ryoku-pkg-add intel-ipu7-camera-bin
fi
