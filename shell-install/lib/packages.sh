#!/bin/bash

# Reads the shared package manifests and hands package names to the active
# distro adapter. Distro-agnostic: it never names a real package itself.

# rsi_read_manifest FILE... -> package names, one per line. Skips comments,
# blank lines, and any line inside an `# @os-only`/`# @end` region (the OS
# install owns those: bootloader, display manager, kernel hooks).
rsi_read_manifest() {
  awk '
    /^[[:space:]]*#[[:space:]]*@os-only/ { skip = 1; next }
    /^[[:space:]]*#[[:space:]]*@end/     { skip = 0; next }
    /^[[:space:]]*#/ { next }
    { sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+$/, "") }
    $0 == "" || skip { next }
    { print }
  ' "$@"
}

# Full system update, its own phase before anything Ryoku is pulled or built.
rsi_system_update() {
  rsi_header "Updating your system (avoids partial upgrades)"
  ryoku_distro_system_update
}

rsi_install_packages() {
  rsi_header "Installing Ryoku packages"
  ryoku_distro_prereqs
  ryoku_distro_install_full
  rsi_ok "dependencies satisfied"
}

# Build and install in-tree packages that are not on official repos or the AUR
# (currently: cava-ryoku, which provides libcava needed by the shell plugin).
# Must run after rsi_install_packages so makedepends are already present.
rsi_install_local_packages() {
  rsi_header "Building local packages"
  ryoku_distro_install_local_pkgs
}
