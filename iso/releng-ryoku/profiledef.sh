#!/usr/bin/env bash
# shellcheck disable=SC2034

# Ryoku Arch live ISO profile, derived from the upstream archiso `releng`
# profile. Layers Ryoku branding (motd, welcome banner) and a one-shot
# `ryoku-install` helper that wraps archinstall + boot.sh for first-time
# users. Build with: sudo mkarchiso -v -w <work-dir> -o <out-dir> <profile-dir>

iso_name="ryoku-arch"
iso_label="RYOKU_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="Ryoku Arch <https://github.com/neur0map/ryoku-arch>"
iso_application="Ryoku Arch Live/Installer ISO"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="ryoku"
buildmodes=('iso')
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/sudoers.d"]="0:0:750"
  ["/etc/sudoers.d/ryoku"]="0:0:440"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/root/.gnupg"]="0:0:700"
  ["/home/ryoku"]="1000:1000:750"
  ["/home/ryoku/.bash_profile"]="1000:1000:644"
  ["/home/ryoku/.config"]="1000:1000:755"
  ["/home/ryoku/.config/hypr"]="1000:1000:755"
  ["/home/ryoku/.config/hypr/hyprland.conf"]="1000:1000:644"
  ["/home/ryoku/.config/alacritty"]="1000:1000:755"
  ["/home/ryoku/.config/alacritty/alacritty.toml"]="1000:1000:644"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/Installation_guide"]="0:0:755"
  ["/usr/local/bin/livecd-sound"]="0:0:755"
  ["/usr/local/bin/ryoku-install"]="0:0:755"
  ["/usr/local/bin/ryoku-welcome"]="0:0:755"
)
