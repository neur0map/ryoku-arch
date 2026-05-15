# Install Panther Lake kernel for Dell XPS Panther Lake systems.
# Other Panther Lake systems stay on stock linux and install sof-firmware.

if ryoku-hw-match "XPS" && ryoku-hw-intel-ptl; then
  echo "Detected Dell XPS Panther Lake, installing PTL kernel..."

  if [[ -n ${RYOKU_CHROOT_INSTALL:-} && -z ${RYOKU_ONLINE_INSTALL:-} ]]; then
    echo "Ryoku ISO does not bundle linux-ptl yet; keeping stock linux for offline install."
    exit 0
  fi

  if ! ryoku-pkg-add linux-ptl linux-ptl-headers; then
    echo "linux-ptl packages are unavailable; keeping stock linux kernel."
    exit 0
  fi

  for pkg in linux linux-headers; do
    sudo pacman -Rdd --noconfirm "$pkg" 2>/dev/null || true
  done

  sudo mkdir -p /etc/limine-entry-tool.d
  cat <<EOF | sudo tee /etc/limine-entry-tool.d/ryoku-dell-xps-panther-lake.conf >/dev/null
# Only show Panther Lake kernel in boot menu on Dell XPS Panther Lake
BOOT_ORDER="linux-ptl*, *fallback, Snapshots"
EOF
fi
