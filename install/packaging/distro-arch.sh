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

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"

LOCAL_PKGS=(cava-ryoku)

if ! ryoku-cmd-present makepkg; then
  echo "distro-arch: makepkg missing; skipping local PKGBUILD builds (install base-devel)" >&2
  exit 0
fi

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
  if [[ -n "$installed" && "$installed" == "${pkgver}-${pkgrel}" ]]; then
    echo "distro-arch: $pkg ${pkgver}-${pkgrel} already installed"
    continue
  fi

  echo "distro-arch: building $pkg ${pkgver}-${pkgrel} from $pkgdir"
  (cd "$pkgdir" && makepkg --syncdeps --install --noconfirm --needed --clean) || {
    echo "distro-arch: failed to build/install $pkg; continuing" >&2
  }
done
