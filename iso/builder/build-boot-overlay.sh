#!/bin/bash

set -euo pipefail

packages_file="$1"
output_dir="$2"
build_root=$(mktemp -d)
trap 'rm -rf "$build_root"' EXIT

pacman --noconfirm -Sy --needed base-devel git sudo

id -u builder >/dev/null 2>&1 || useradd -m builder
printf '%s\n' 'builder ALL=(ALL) NOPASSWD: ALL' >/etc/sudoers.d/90-builder
chmod 440 /etc/sudoers.d/90-builder

while IFS= read -r pkg; do
  [[ -n $pkg ]] || continue
  work_dir="$build_root/$pkg"

  sudo -u builder git clone --depth=1 "https://aur.archlinux.org/${pkg}.git" "$work_dir"
  pushd "$work_dir" >/dev/null
  sudo -u builder env PKGDEST="$output_dir" makepkg --syncdeps --clean --cleanbuild --noconfirm
  popd >/dev/null
done < "$packages_file"
