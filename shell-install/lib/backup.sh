#!/bin/bash

# Backups for anything the installer would overwrite. Clash-only: a path is
# only backed up if it already exists. Backups mirror their original path
# under a single timestamped per-run directory, and each is recorded in the
# manifest so uninstall can restore it. Each path is backed up at most once
# per run, so the upfront backup and deploy's lazy backups never double up.

RSI_BACKUP_DIR=""
declare -gA RSI_BACKED=()

_rsi_backup_dir() {
  if [[ -z $RSI_BACKUP_DIR ]]; then
    RSI_BACKUP_DIR="$RSI_BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
    rsi_dry || mkdir -p "$RSI_BACKUP_DIR"
  fi
  printf '%s' "$RSI_BACKUP_DIR"
}

# rsi_backup PATH -> if PATH exists (and was not already backed up this run),
# copy it into the per-run backup dir and record it. No-op otherwise.
rsi_backup() {
  local orig="$1"
  [[ -e $orig || -L $orig ]] || return 0
  [[ -n ${RSI_BACKED[$orig]:-} ]] && return 0
  RSI_BACKED[$orig]=1

  local dir backup
  dir="$(_rsi_backup_dir)"
  backup="$dir/${orig#"$HOME"/}"

  if rsi_dry; then
    rsi_dim "  would back up: $orig"
    rsi_record backup "$orig" "$backup"
    return 0
  fi

  mkdir -p "$(dirname "$backup")"
  cp -a -- "$orig" "$backup"
  rsi_record backup "$orig" "$backup"
}

# rsi_backup_setup -> snapshot everything the installer might touch, upfront,
# before any package install or deploy. Reuses the conflict target list.
rsi_backup_setup() {
  rsi_header "Backing up your current setup"
  local t any=0
  while IFS= read -r t; do
    if [[ -e $t || -L $t ]]; then
      rsi_backup "$t"
      any=1
    fi
  done < <(rsi_conflict_targets)

  if (( any == 0 )); then
    rsi_ok "nothing to back up (clean slate)"
  elif ! rsi_dry; then
    rsi_ok "backup saved under $RSI_BACKUP_DIR"
  fi
}
