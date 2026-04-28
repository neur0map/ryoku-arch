#!/bin/bash

set -euo pipefail

packages_file="$1"
output_dir="$2"
build_root=$(mktemp -d)
trap 'rm -rf "$build_root"' EXIT

pacman --noconfirm -Sy --needed base-devel git sudo

# Enable [multilib] so makepkg --syncdeps can pull lib32-* build/runtime
# deps for AUR packages like lib32-nvidia-580xx-utils. Default Arch
# pacman.conf ships [multilib] commented out; sed-uncomment that block
# without touching anything else, then refresh the package db.
if grep -q '^#\[multilib\]' /etc/pacman.conf; then
  sed -i '/^#\[multilib\]$/,/^#Include/ s/^#//' /etc/pacman.conf
  pacman --noconfirm -Sy
fi

# Some AUR PKGBUILDs (DKMS modules, kernels) have hard build-deps that
# makepkg --syncdeps will pull. Pre-install the common ones so each
# package does not redo the dep resolution from scratch.
pacman --noconfirm -S --needed dkms

id -u builder >/dev/null 2>&1 || useradd -m builder
printf '%s\n' 'builder ALL=(ALL) NOPASSWD: ALL' >/etc/sudoers.d/90-builder
chmod 440 /etc/sudoers.d/90-builder

# build_root was created by root via mktemp; the builder user needs to
# write to it for git clone and for makepkg's own scratch files.
chown builder:builder "$build_root"
chown builder:builder "$output_dir"

# Skip blank lines and comments (lines starting with #) so the
# overlay manifest can carry inline documentation without each
# comment being treated as a package name to clone from AUR.
while IFS= read -r pkg; do
  pkg="${pkg%%#*}"
  pkg="${pkg// /}"
  pkg="${pkg//$'\t'/}"
  [[ -n $pkg ]] || continue
  work_dir="$build_root/$pkg"

  sudo -u builder git clone --depth=1 "https://aur.archlinux.org/${pkg}.git" "$work_dir"
  pushd "$work_dir" >/dev/null
  sudo -u builder env PKGDEST="$output_dir" makepkg --syncdeps --clean --cleanbuild --force --noconfirm
  popd >/dev/null
done < "$packages_file"
