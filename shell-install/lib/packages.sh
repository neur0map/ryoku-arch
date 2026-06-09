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

# Build and install the in-tree distro packages (cava-ryoku -> libcava for the
# music visualizer, ryoku-tui) through the SAME script the OS install and
# ryoku-update use, so there is exactly one cava-build path. Prebuilt-first
# (pacman -U the tracked .pkg.tar.zst), makepkg fallback. Runs before the shell
# build so CMake finds libcava. Non-fatal: a missing libcava only disables the
# visualizer.
rsi_install_distro_packages() {
  rsi_header "Building local packages (cava-ryoku, ryoku-tui)"
  local script="$RSI_REPO/install/packaging/distro-arch.sh"
  if [[ ! -f $script ]]; then
    rsi_warn "no $script; skipping in-tree packages (audio visualizer may be disabled)"
    return 0
  fi
  if rsi_dry; then
    rsi_dim "  would run install/packaging/distro-arch.sh (prebuilt cava-ryoku via pacman -U, else makepkg)"
    return 0
  fi
  RYOKU_PATH="$RSI_REPO" bash "$script" || rsi_warn "distro packaging reported a problem; audio visualizer may be disabled"
}
