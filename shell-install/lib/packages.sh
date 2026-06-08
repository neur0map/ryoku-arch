#!/bin/bash

# Reads the logical dependency list and hands it to the active distro adapter.
# Distro-agnostic: it never names a real package.

# rsi_read_deps -> echo logical dep names, one per line (comments stripped).
rsi_read_deps() {
  local line
  while IFS= read -r line || [[ -n $line ]]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -n $line ]] && printf '%s\n' "$line"
  done <"$RSI_DEPS_FILE"
}

# Full system update, its own phase before anything Ryoku is pulled or built.
rsi_system_update() {
  rsi_header "Updating your system (avoids partial upgrades)"
  ryoku_distro_system_update
}

rsi_install_packages() {
  rsi_header "Installing Ryoku packages"
  ryoku_distro_prereqs

  if [[ ${RSI_MINIMAL:-0} == 1 ]]; then
    rsi_step "minimal mode: shell-critical packages only"
    local deps=()
    mapfile -t deps < <(rsi_read_deps)
    [[ ${#deps[@]} -gt 0 ]] || rsi_die "no logical deps found in $RSI_DEPS_FILE"
    ryoku_distro_install "${deps[@]}"
  else
    ryoku_distro_install_full
  fi
  rsi_ok "dependencies satisfied"
}

# Build and install in-tree packages that are not on official repos or the AUR
# (currently: cava-ryoku, which provides libcava needed by the shell plugin).
# Must run after rsi_install_packages so makedepends are already present.
rsi_install_local_packages() {
  rsi_header "Building local packages"
  ryoku_distro_install_local_pkgs
}
