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

rsi_install_packages() {
  rsi_step "resolving dependencies via the $RSI_FAMILY adapter"
  ryoku_distro_prereqs

  local deps=()
  mapfile -t deps < <(rsi_read_deps)
  [[ ${#deps[@]} -gt 0 ]] || rsi_die "no logical deps found in $RSI_DEPS_FILE"

  ryoku_distro_install "${deps[@]}"
  rsi_ok "dependencies satisfied"
}
