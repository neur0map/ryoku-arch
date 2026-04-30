#!/bin/bash
#
# Build every AUR package listed across one or more manifests into the
# offline mirror. Called by iso/builder/build-iso.sh with both
# iso/builder/ryoku-boot-overlay.packages (boot infra + conditional
# hardware AUR drivers) and install/ryoku-aur.packages (default-install
# AUR apps and CLIs). The built .pkg.tar.zst files land in $output_dir
# and get repo-add'd into the [offline] mirror later in build-iso.sh.

set -euo pipefail

if (($# < 2)); then
  echo "Usage: $0 <packages_file> [<more_packages_files>...] <output_dir>" >&2
  exit 2
fi

# Last positional arg is the output dir; everything before is a packages manifest.
output_dir="${@: -1}"
packages_files=("${@:1:$#-1}")

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

# Concatenate all manifests; skip blank lines and comments so each
# manifest can carry inline documentation without each comment being
# treated as a package name to clone from AUR. Dedupe so a package
# listed in two manifests is built once.
declare -A seen=()
while IFS= read -r pkg; do
  pkg="${pkg%%#*}"
  pkg="${pkg// /}"
  pkg="${pkg//$'\t'/}"
  [[ -n $pkg ]] || continue
  [[ -z ${seen[$pkg]:-} ]] || continue
  seen[$pkg]=1

  work_dir="$build_root/$pkg"

  sudo -u builder git clone --depth=1 "https://aur.archlinux.org/${pkg}.git" "$work_dir"
  pushd "$work_dir" >/dev/null
  sudo -u builder env PKGDEST="$output_dir" makepkg --syncdeps --clean --cleanbuild --force --noconfirm
  popd >/dev/null
done < <(cat "${packages_files[@]}")
