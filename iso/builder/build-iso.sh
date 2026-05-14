#!/bin/bash

set -e

# Note that these are packages installed to the Arch container used to build the ISO.
pacman-key --init
pacman --noconfirm -Sy archlinux-keyring
pacman --noconfirm -Sy archiso git sudo base-devel jq grub uv neovim cairo gobject-introspection glib2 pkgconf

# We do not yet ship a custom [ryoku] pacman repo / keyring (omarchy
# parity item, but signing infrastructure is out of scope right now).
# Skipping the keyring install: packages are pulled from official Arch
# repos only.

# Setup build locations
build_cache_dir="/var/cache"
offline_mirror_dir="$build_cache_dir/airootfs/var/cache/ryoku/mirror/offline"
mkdir -p $build_cache_dir/
mkdir -p $offline_mirror_dir/

# We base our ISO on the official arch ISO (releng) config that ships
# with the archiso package we just installed.
cp -r /usr/share/archiso/configs/releng/* $build_cache_dir/
rm "$build_cache_dir/airootfs/etc/motd"

# Avoid using reflector for mirror identification as we are relying on the global CDN
rm -rf "$build_cache_dir/airootfs/etc/systemd/system/multi-user.target.wants/reflector.service"
rm -rf "$build_cache_dir/airootfs/etc/systemd/system/reflector.service.d"
rm -rf "$build_cache_dir/airootfs/etc/xdg/reflector"

# Bring in our configs
cp -r /configs/* $build_cache_dir/

# Persist RYOKU_MIRROR so it's available at install time
echo "$RYOKU_MIRROR" > "$build_cache_dir/airootfs/root/ryoku_mirror"

cat > "$build_cache_dir/airootfs/etc/ryoku-iso-release" <<EOF
TRACKING_ID=${RYOKU_ISO_TRACKING_ID:-unknown}
INSTALLER_REPO=${RYOKU_INSTALLER_REPO:-unknown}
INSTALLER_REF=${RYOKU_INSTALLER_REF:-unknown}
MIRROR=${RYOKU_MIRROR:-unknown}
BUILD_SHA=${RYOKU_ISO_BUILD_SHA:-unknown}
BUILD_URL=${RYOKU_ISO_BUILD_URL:-}
SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-}
EOF

# Setup Ryoku itself
if [[ -d /ryoku ]]; then
  /bin/bash /builder/sync-local-source.sh /ryoku "$build_cache_dir/airootfs/root/ryoku"
else
  git clone -b $RYOKU_INSTALLER_REF https://github.com/$RYOKU_INSTALLER_REPO.git "$build_cache_dir/airootfs/root/ryoku"
fi

# Ryoku shell comes from the vendored shell/ tree in this Ryoku repo.
# A separate /ryoku-shell mount is only for local-source shell development.
if [[ -d /ryoku-shell ]]; then
  rm -rf "$build_cache_dir/airootfs/root/ryoku/shell"
  /bin/bash /builder/sync-local-source.sh /ryoku-shell "$build_cache_dir/airootfs/root/ryoku/shell"
elif [[ -d /ryoku/shell ]]; then
  true
else
  echo "build-iso: no Ryoku shell/ tree available at /ryoku/shell" >&2
  exit 1
fi

shell_requirements="$build_cache_dir/airootfs/root/ryoku/shell/sdata/uv/requirements.txt"
shell_uv_cache="$build_cache_dir/airootfs/var/cache/ryoku/uv"
if [[ -f $shell_requirements ]]; then
  mkdir -p "$shell_uv_cache"
  shell_uv_venv=$(mktemp -d)
  UV_CACHE_DIR="$shell_uv_cache" uv venv --prompt ryoku-shell-cache "$shell_uv_venv"
  VIRTUAL_ENV="$shell_uv_venv" UV_CACHE_DIR="$shell_uv_cache" uv pip install -r "$shell_requirements"
  rm -rf "$shell_uv_venv"
fi

# Stage non-pacman AppImage artifacts needed by the installer. These are
# not valid pacman repo entries, so they live beside the offline mirror and
# are bind-mounted into the target chroot by the ISO automation.
offline_appimages_manifest="/builder/ryoku-offline-appimages.tsv"
offline_appimages_dir="$build_cache_dir/airootfs/var/cache/ryoku/appimages"

if [[ -f $offline_appimages_manifest ]]; then
  mkdir -p "$offline_appimages_dir"

  while IFS=$'\t' read -r app_name github_repo asset_regex; do
    [[ -n $app_name && $app_name != \#* ]] || continue
    [[ -n $github_repo && -n $asset_regex ]] || continue

    app_cache_dir="$offline_appimages_dir/$app_name"
    release_json="$app_cache_dir/release.json"
    mkdir -p "$app_cache_dir"

    curl -fsSL "https://api.github.com/repos/$github_repo/releases/latest" -o "$release_json"

    asset_name="$(
      jq -r --arg regex "$asset_regex" '
        .assets[]?
        | select(.name | test($regex))
        | .name // empty
      ' "$release_json" | head -n1
    )"
    download_url="$(
      jq -r --arg regex "$asset_regex" '
        .assets[]?
        | select(.name | test($regex))
        | .browser_download_url // empty
      ' "$release_json" | head -n1
    )"

    if [[ -z $asset_name || -z $download_url ]]; then
      echo "build-iso: no AppImage asset matched $asset_regex for $github_repo" >&2
      exit 1
    fi

    if [[ ! -s "$app_cache_dir/$asset_name" ]]; then
      curl -fL --retry 3 --connect-timeout 10 --max-time 600 \
        -o "$app_cache_dir/$asset_name" "$download_url"
    fi

    chmod 0755 "$app_cache_dir/$asset_name"
    ln -sfn "$asset_name" "$app_cache_dir/$app_name.AppImage"
  done < "$offline_appimages_manifest"
fi

# Copy the Ryoku Plymouth theme to the ISO if the installer ships one.
if [[ -d "$build_cache_dir/airootfs/root/ryoku/default/plymouth" ]]; then
  mkdir -p "$build_cache_dir/airootfs/usr/share/plymouth/themes/ryoku"
  cp -r "$build_cache_dir/airootfs/root/ryoku/default/plymouth/"* \
        "$build_cache_dir/airootfs/usr/share/plymouth/themes/ryoku/"
fi

# Add our additional packages to packages.x86_64. Apple T2 (linux-t2)
# is omarchy-only (DHH ships MacBooks); we use the standard linux
# kernel that the releng base already pulls.
arch_packages=(git gum jq neovim openssl plymouth)
printf '%s\n' "${arch_packages[@]}" >>"$build_cache_dir/packages.x86_64"

nvim_config_dir="$build_cache_dir/airootfs/root/ryoku/config/nvim"
nvim_cache_dir="$build_cache_dir/airootfs/var/cache/ryoku/nvim"
if [[ -f $nvim_config_dir/init.lua ]]; then
  nvim_prefetch_home="$(mktemp -d)"
  mkdir -p "$nvim_prefetch_home/config" "$nvim_prefetch_home/data" "$nvim_prefetch_home/state" "$nvim_prefetch_home/cache"
  cp -a "$nvim_config_dir" "$nvim_prefetch_home/config/nvim"
  cat >"$nvim_prefetch_home/config/nvim/lua/plugins/ryoku-offline-cache.lua" <<'EOF'
return {
  {
    "yukazakiri/ryoku.nvim",
    lazy = true,
  },
}
EOF
  XDG_CONFIG_HOME="$nvim_prefetch_home/config" \
  XDG_DATA_HOME="$nvim_prefetch_home/data" \
  XDG_STATE_HOME="$nvim_prefetch_home/state" \
  XDG_CACHE_HOME="$nvim_prefetch_home/cache" \
    nvim --headless "+Lazy! sync" +qa
  mkdir -p "$nvim_cache_dir"
  cp -a "$nvim_prefetch_home/data/nvim/." "$nvim_cache_dir/"
  rm -rf "$nvim_prefetch_home"
fi

# Build the AUR overlay into the offline mirror BEFORE downloading the
# official packages. Two manifests feed this step:
#
#   iso/builder/ryoku-boot-overlay.packages
#     Boot-critical (limine hooks) + AUR-only conditional hardware
#     drivers (NVIDIA legacy, asusctl, qmk-hid, intel-lpmd, etc.).
#
#   install/ryoku-aur.packages
#     Default-install AUR apps and CLIs (1password, localsend,
#     spotify, typora, tofi, ...). Baking these into the
#     mirror lets aur-core.sh use a pacman -S resolved from [offline]
#     instead of reaching out to AUR over the network on first boot.
#
# Both lists end up in the same offline-mirror flat directory so the
# rest of the pipeline (overlay-strip filter, repo-add) only needs one
# union to reason about.
aur_overlay_manifest="/builder/ryoku-boot-overlay.packages"
aur_default_manifest="$build_cache_dir/airootfs/root/ryoku/install/ryoku-aur.packages"

mapfile -t overlay_packages < <(
  {
    grep -v '^#' "$aur_overlay_manifest" | grep -v '^$'
    grep -v '^#' "$aur_default_manifest" | grep -v '^$'
  } | awk 'NF { print }'
)

/bin/bash /builder/build-boot-overlay.sh \
  "$aur_overlay_manifest" \
  "$aur_default_manifest" \
  "$offline_mirror_dir"

# Build list of all the packages needed for the offline mirror.
# ryoku-base.packages is what every install pacstraps; ryoku-other.packages
# is what conditional hardware scripts (vulkan.sh, nvidia.sh,
# intel/video-acceleration.sh, fix-bcm43xx.sh, etc.) might pacman-install
# on the matching hardware. ryoku-aur.packages is what aur-core.sh
# pacstraps from the [offline] mirror. All three are pulled into the
# mirror so a truly offline install on real hardware has every driver
# and default app reachable in [offline].
mapfile -t all_packages < <(
  {
    cat "$build_cache_dir/packages.x86_64"
    grep -v '^#' "$build_cache_dir/airootfs/root/ryoku/install/ryoku-base.packages" | grep -v '^$'
    grep -v '^#' "$build_cache_dir/airootfs/root/ryoku/install/ryoku-other.packages" | grep -v '^$'
    grep -v '^#' "$aur_default_manifest" | grep -v '^$'
    grep -v '^#' /builder/archinstall.packages | grep -v '^$'
  } | awk 'NF { print }'
)

# Drop AUR-overlay packages from the official-mirror download list so
# pacman doesn't try to fetch them from the Arch CDN (they live in AUR
# and were just makepkg'd into the offline mirror above).
official_packages=()
for pkg in "${all_packages[@]}"; do
  skip=0
  for overlay_pkg in "${overlay_packages[@]}"; do
    if [[ $pkg == "$overlay_pkg" ]]; then
      skip=1
      break
    fi
  done
  (( skip == 0 )) && official_packages+=("$pkg")
done

# Download all the packages to the offline mirror inside the ISO
mkdir -p /tmp/offlinedb
pacman --config /configs/pacman-online-${RYOKU_MIRROR}.conf \
  --noconfirm -Syw "${official_packages[@]}" \
  --cachedir "$offline_mirror_dir/" --dbpath /tmp/offlinedb

# Drop any prior db so repo-add always reflects this build's actual
# package files. With --new (skip-if-present), an overlay package
# rebuilt with a different byte size would still carry the old
# %CSIZE% entry and pacman would reject it as size-mismatched.
rm -f "$offline_mirror_dir/offline.db.tar.gz" \
      "$offline_mirror_dir/offline.db" \
      "$offline_mirror_dir/offline.files.tar.gz" \
      "$offline_mirror_dir/offline.files"

repo-add "$offline_mirror_dir/offline.db.tar.gz" "$offline_mirror_dir/"*.pkg.tar.zst

# Create a symlink to the offline mirror instead of duplicating it.
# mkarchiso needs packages at /var/cache/ryoku/mirror/offline in the container,
# but they're actually in $build_cache_dir/airootfs/var/cache/ryoku/mirror/offline
mkdir -p /var/cache/ryoku/mirror
ln -s "$offline_mirror_dir" "/var/cache/ryoku/mirror/offline"

# Copy the offline pacman.conf to the ISO's /etc directory so the live environment uses our
# same config when booted. 
cp $build_cache_dir/pacman-offline.conf "$build_cache_dir/airootfs/etc/pacman.conf"

# Finally, we assemble the entire ISO
mkarchiso -v -w "$build_cache_dir/work/" -o "/out/" "$build_cache_dir/"

# Fix ownership of output files to match host user
if [ -n "$HOST_UID" ] && [ -n "$HOST_GID" ]; then
    chown -R "$HOST_UID:$HOST_GID" /out/
fi
