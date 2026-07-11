#!/usr/bin/env bash
# shellcheck disable=SC2034
#
# Ryoku live ISO profile (archiso, releng-based).
#
# boots straight into the installer TUI on tty1 (autologin root -> cage + foot
# -> ryoku-tui). serial console (ttyS0) stays a plain root shell for headless /
# recovery. the prebuilt TUI + backend + repo get baked into airootfs by
# build.sh, not committed here.

iso_name="ryoku"
iso_label="RYOKU_$(date -u --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="Ryoku Linux <https://ryoku.sh>"
iso_application="Ryoku Linux Installer"
iso_version="$(date -u --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '19' '-b' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.bash_profile"]="0:0:644"
  ["/root/.zlogin"]="0:0:644"
  ["/usr/local/bin/ryoku-installer-session"]="0:0:755"
  ["/usr/local/bin/ryoku-install"]="0:0:755"
  ["/usr/local/bin/ryoku-tui"]="0:0:755"
  ["/usr/local/lib/ryoku/backend/ryoku-install"]="0:0:755"
)
