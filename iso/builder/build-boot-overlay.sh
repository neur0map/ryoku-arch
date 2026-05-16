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
output_dir="${!#}"
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

# Some AUR packages declare rustup as a build dep. Keep this rustup
# swap confined to the ISO build container: installed Ryoku systems ship
# Arch rust, and default AUR packages should avoid rustup make-deps so
# user updates do not hit rust/rustup package conflicts.
if pacman -Q rust >/dev/null 2>&1; then
  pacman -Rdd --noconfirm rust || true
fi
pacman --noconfirm -S --needed rustup
# rustup state is per-user. We set default toolchain for both root (so
# any container-level cargo call works) and the `builder` user (created
# below) since makepkg runs as builder via sudo -u and has its own
# RUSTUP_HOME at ~builder/.rustup.
rustup default stable

id -u builder >/dev/null 2>&1 || useradd -m builder
printf '%s\n' 'builder ALL=(ALL) NOPASSWD: ALL' >/etc/sudoers.d/90-builder
chmod 440 /etc/sudoers.d/90-builder

# Set rustup default for the builder user too. makepkg runs as builder
# via sudo -u, so its rustup invocations look at ~builder/.rustup, not
# ~root/.rustup. Without this, AUR packages whose build() invokes cargo
# (tzupdate, anything with rust/cargo build deps) abort with "rustup
# could not choose a version of cargo to run".
sudo -u builder rustup default stable

# build_root was created by root via mktemp; the builder user needs to
# write to it for git clone and for makepkg's own scratch files.
chown builder:builder "$build_root"
chown builder:builder "$output_dir"

aur_fetch_plain_repo() {
  local pkg="$1"
  local work_dir="$2"
  local tree_html="$work_dir/.aur-tree.html"
  local file_path
  local file_url
  local file_paths=()

  mkdir -p "$work_dir"

  if ! curl -fsSL --connect-timeout 20 --retry 5 --retry-all-errors --retry-delay 5 \
    "https://aur.archlinux.org/cgit/aur.git/tree/?h=${pkg}" \
    -o "$tree_html"; then
    echo "cgit tree fetch of $pkg from AUR failed." >&2
    return 1
  fi

  mapfile -t file_paths < <(
    grep -Eo '/cgit/aur\.git/plain/[^"?]+\?h=[^"]+' "$tree_html" |
      sed -E 's#^/cgit/aur\.git/plain/([^?]+)\?h=.*#\1#' |
      sort -u
  )

  if ((${#file_paths[@]} == 0)); then
    echo "cgit tree for $pkg did not list any plain files." >&2
    return 1
  fi

  for file_path in "${file_paths[@]}"; do
    file_url="https://aur.archlinux.org/cgit/aur.git/plain/$file_path?h=${pkg}"
    mkdir -p "$(dirname "$work_dir/$file_path")"
    if ! curl -fsSL --connect-timeout 20 --retry 5 --retry-all-errors --retry-delay 5 \
      "$file_url" \
      -o "$work_dir/$file_path"; then
      echo "cgit plain fetch of $pkg/$file_path from AUR failed." >&2
      return 1
    fi
  done

  rm -f "$tree_html"
  [[ -f $work_dir/PKGBUILD ]] || {
    echo "cgit fallback for $pkg did not produce a PKGBUILD." >&2
    return 1
  }
  chown -R builder:builder "$work_dir"
}

aur_clone() {
  local pkg="$1"
  local work_dir="$2"
  local attempt
  local sleep_seconds

  for attempt in {1..5}; do
    if sudo -u builder git -c http.version=HTTP/1.1 clone --depth=1 "https://aur.archlinux.org/${pkg}.git" "$work_dir"; then
      return 0
    fi

    rm -rf "$work_dir"

    if (( attempt < 5 )); then
      sleep_seconds=$(( attempt * 10 ))
      echo "git clone of $pkg from AUR failed (attempt $attempt/5), retrying in ${sleep_seconds}s..." >&2
      sleep "$sleep_seconds"
    fi
  done

  echo "git clone of $pkg from AUR failed after 5 attempts; trying cgit plain fallback." >&2
  aur_fetch_plain_repo "$pkg" "$work_dir"
}

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

  aur_clone "$pkg" "$work_dir"
  pushd "$work_dir" >/dev/null
  # --skippgpcheck: some AUR packages (1password, etc.) sign source
  # tarballs with vendor PGP keys that aren't trusted in the empty build
  # container keyring. Skipping verification here is acceptable for
  # offline-mirror builds - the resulting .pkg.tar.zst is then signed by
  # OUR ISO key downstream (ryoku-iso-sign), which is what users verify.
  # For a hardened release flow, replace --skippgpcheck with explicit
  # gpg --recv-keys for the vendor keys we trust.
  sudo -u builder env PKGDEST="$output_dir" makepkg --syncdeps --clean --cleanbuild --force --noconfirm --skippgpcheck
  popd >/dev/null
done < <(cat "${packages_files[@]}")
