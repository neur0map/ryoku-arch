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

# build_root was created by root via mktemp; the builder user needs to
# write to it for git clone and for makepkg's own scratch files.
chown builder:builder "$build_root"
chown builder:builder "$output_dir"

while IFS= read -r pkg; do
  [[ -n $pkg ]] || continue
  work_dir="$build_root/$pkg"

  sudo -u builder git clone --depth=1 "https://aur.archlinux.org/${pkg}.git" "$work_dir"
  pushd "$work_dir" >/dev/null
  sudo -u builder env PKGDEST="$output_dir" makepkg --syncdeps --clean --cleanbuild --force --noconfirm
  popd >/dev/null
done < "$packages_file"
