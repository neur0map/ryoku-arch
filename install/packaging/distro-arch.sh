#!/bin/bash

# Build + install the local Ryoku PKGBUILDs under distro/arch/. These
# are not on the AUR (so install/ryoku-aur.packages can't list them);
# they ship in-tree because they replace stock Arch packages with
# Ryoku-patched versions:
#
#   cava-ryoku        - cava + libcava (rebirth shell plugin requires
#                       libcava; stock cava omits the shared library)
#
# quickshell-ryoku and qt6-qiooperation-patch are intentionally NOT
# listed here. quickshell-ryoku is a developer-bootstrap PKGBUILD
# (manual `makepkg -si` once per machine, then pinned via IgnorePkg);
# qt6-qiooperation-patch uses its own apply.sh binary-patching path.

set -euo pipefail

script_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$script_root/lib/runtime-env.sh"

LOCAL_PKGS=(cava-ryoku)

distro_libcava_present() {
  if ryoku-cmd-present pkgconf && pkgconf --exists libcava; then
    return 0
  fi

  if ryoku-cmd-present pkg-config && pkg-config --exists libcava; then
    return 0
  fi

  [[ -f /usr/lib/pkgconfig/libcava.pc ]]
}

for pkg in "${LOCAL_PKGS[@]}"; do
  pkgdir="$RYOKU_PATH/distro/arch/$pkg"
  if [[ ! -f "$pkgdir/PKGBUILD" ]]; then
    echo "distro-arch: missing $pkgdir/PKGBUILD; skipping $pkg" >&2
    continue
  fi

  # Skip if already installed at the same version-rel as the PKGBUILD declares.
  pkgver="$(awk -F= '/^pkgver=/{gsub(/[\047"]/,"",$2); print $2}' "$pkgdir/PKGBUILD")"
  pkgrel="$(awk -F= '/^pkgrel=/{gsub(/[\047"]/,"",$2); print $2}' "$pkgdir/PKGBUILD")"
  installed="$(pacman -Q "$pkg" 2>/dev/null | awk '{print $2}' || true)"
  if [[ -n $installed && $installed == "${pkgver}-${pkgrel}" ]]; then
    if distro_libcava_present; then
      echo "distro-arch: $pkg ${pkgver}-${pkgrel} already installed and libcava is available"
      continue
    fi
    echo "distro-arch: $pkg ${pkgver}-${pkgrel} is installed but libcava is not available; reinstalling"
  fi

  arch="$(uname -m)"
  prebuilt_pkg="$pkgdir/${pkg}-${pkgver}-${pkgrel}-${arch}.pkg.tar.zst"
  use_prebuilt=0
  if [[ -f $prebuilt_pkg ]]; then
    use_prebuilt=1
  elif ! ryoku-cmd-present makepkg; then
    echo "distro-arch: makepkg missing and no bundled $pkg package found for $arch; skipping $pkg" >&2
    continue
  fi

  # pacman -U --noconfirm aborts on a conflict (e.g. cava-ryoku declares
  # conflicts=(cava), but stock cava is already installed from
  # install/packaging/base.sh - the offline mirror must satisfy
  # `cava` for the base step, so it landed). Pre-remove any
  # conflicting installed package via -Rdd (no dep check; the new
  # package supplies the same provides= entry).
  conflicts_line="$(awk -F= '/^conflicts=/{
      gsub(/[()'\''"]/, "", $2); print $2
  }' "$pkgdir/PKGBUILD")"
  for c in $conflicts_line; do
    [[ -n $c ]] || continue
    if pacman -Qq "$c" >/dev/null 2>&1; then
      echo "distro-arch: removing conflicting installed $c before installing $pkg"
      sudo pacman -Rdd --noconfirm "$c" || true
    fi
  done

  if (( use_prebuilt )); then
    echo "distro-arch: installing bundled $pkg ${pkgver}-${pkgrel} from $prebuilt_pkg"
    sudo pacman -U --noconfirm --needed "$prebuilt_pkg" || {
      echo "distro-arch: failed to install bundled $pkg" >&2
      exit 1
    }
  else
    echo "distro-arch: building $pkg ${pkgver}-${pkgrel} from $pkgdir"
    (cd "$pkgdir" && makepkg --syncdeps --install --noconfirm --needed --clean) || {
      echo "distro-arch: failed to build/install $pkg" >&2
      exit 1
    }
  fi

  if ! distro_libcava_present; then
    echo "distro-arch: $pkg did not provide libcava after install; aborting before shell build" >&2
    exit 1
  fi
done
