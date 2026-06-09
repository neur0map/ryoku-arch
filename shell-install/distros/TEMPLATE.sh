#!/bin/bash

# Distro adapter template. Copy to <family>.sh, register the family's distro
# IDs in detect.sh (rsi_detect_family), and implement the contract functions
# below. Nothing outside shell-install/distros/ should need to change to add a
# distro, so the OS/ISO installer is never affected.
#
# Package data lives in the shared manifests (install/ryoku-*.packages); an
# adapter only decides HOW to install, never WHAT. Record installed packages
# with `rsi_record pkg NAME` so --purge-packages works.

# ryoku_distro_system_update
#   Bring the whole system up to date BEFORE anything is installed, so new
#   packages do not land against stale libraries (a partial upgrade, which can
#   break the user's existing apps). Refresh signing keys first if the distro
#   needs it. Honour rsi_dry.
ryoku_distro_system_update() {
  rsi_die "ryoku_distro_system_update not implemented for this distro"
}

# ryoku_distro_prereqs
#   Ensure build tools and any helper (AUR, COPR, ...) are ready. Runs after
#   the system update.
ryoku_distro_prereqs() {
  rsi_die "ryoku_distro_prereqs not implemented for this distro"
}

# ryoku_distro_install_full
#   Install the full Ryoku package set. Read the shared manifests with
#   rsi_read_manifest "$RSI_BASE_PACKAGES" "$RSI_AUR_PACKAGES" (it already skips
#   the `# @os-only` regions the OS install owns), then install the missing
#   packages your way. Honour rsi_dry and record installed packages.
ryoku_distro_install_full() {
  rsi_die "ryoku_distro_install_full not implemented for this distro"
}

# ryoku_distro_install_local_pkgs
#   Build and install any in-tree packages that are not on official repos or
#   the AUR (e.g. patched forks that provide additional libraries). Called
#   after ryoku_distro_install so repo deps are already present. No-op on
#   distros that do not need local builds.
ryoku_distro_install_local_pkgs() { :; }
