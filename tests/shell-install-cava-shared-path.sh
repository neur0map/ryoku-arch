#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

cd "$ROOT_DIR"

# There must be exactly ONE cava-ryoku build path: the shared
# install/packaging/distro-arch.sh that the OS install and ryoku-update use.
# The standalone's own duplicate (ryoku_distro_install_local_pkgs) must be gone.
! grep -rq 'ryoku_distro_install_local_pkgs' shell-install/ \
  || fail "the duplicate standalone cava build (ryoku_distro_install_local_pkgs) must be removed"
grep -q 'packaging/distro-arch.sh' shell-install/lib/packages.sh \
  || fail "standalone must build cava via the shared install/packaging/distro-arch.sh"
grep -q 'rsi_install_distro_packages' shell-install/install \
  || fail "shell-install/install must call rsi_install_distro_packages"
! grep -rq 'rsi_install_local_packages' shell-install/ \
  || fail "the old rsi_install_local_packages wrapper must be removed"

printf 'PASS: tests/shell-install-cava-shared-path.sh\n'
