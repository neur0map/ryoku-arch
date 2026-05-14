#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="ryoku"
iso_label="RYOKU_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="Ryoku <https://github.com/neur0map/ryoku-arch>"
iso_application="Ryoku Installer"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.grub')
arch="x86_64"
pacman_conf="pacman-offline.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/root/.gnupg"]="0:0:700"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/root/configurator"]="0:0:755"
  ["/var/cache/ryoku/mirror/offline/"]="0:0:775"
  ["/var/cache/ryoku/nvim/"]="0:0:775"
  ["/var/cache/ryoku/appimages/"]="0:0:775"
  ["/usr/local/bin/ryoku-upload-log"]="0:0:755"
)
