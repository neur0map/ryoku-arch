#!/bin/bash

# Ownership manifest. Every path the installer creates and every backup it
# takes is appended here so uninstall can reverse the run precisely. Format
# is tab-separated: ACTION<TAB>ARG1[<TAB>ARG2].
#
# Actions:
#   link    PATH            a symlink we created
#   dir     PATH            a directory tree we deployed
#   file    PATH            a single file we wrote
#   session PATH            the wayland-session entry (sudo to remove)
#   service UNIT            a user systemd unit we enabled
#   backup  ORIG  BACKUP    original moved/copied to BACKUP before we wrote ORIG
#   pkg     NAME            a package this run installed (for --purge-packages)

rsi_manifest_init() {
  rsi_dry && return 0
  mkdir -p "$RSI_STATE_DIR"
  [[ -f $RSI_MANIFEST ]] || : >"$RSI_MANIFEST"
}

# rsi_record ACTION ARG... -> append one manifest line.
rsi_record() {
  local action="$1"
  shift
  if rsi_dry; then
    rsi_dim "  would record: $action	$*"
    return 0
  fi
  local line="$action"
  local arg
  for arg in "$@"; do
    line+=$'\t'"$arg"
  done
  printf '%s\n' "$line" >>"$RSI_MANIFEST"
}
