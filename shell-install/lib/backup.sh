#!/bin/bash

# Backups for anything the installer would overwrite. Clash-only: a path is
# only backed up if it already exists. Backups mirror their original path
# under a single timestamped per-run directory, and each is recorded in the
# manifest so uninstall can restore it.

RSI_BACKUP_DIR=""

_rsi_backup_dir() {
  if [[ -z $RSI_BACKUP_DIR ]]; then
    RSI_BACKUP_DIR="$RSI_BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
    rsi_dry || mkdir -p "$RSI_BACKUP_DIR"
  fi
  printf '%s' "$RSI_BACKUP_DIR"
}

# rsi_backup PATH -> if PATH exists (and is not one of our own symlinks),
# copy it into the per-run backup dir and record it. No-op otherwise.
rsi_backup() {
  local orig="$1"
  [[ -e $orig || -L $orig ]] || return 0

  local dir backup
  dir="$(_rsi_backup_dir)"
  backup="$dir/${orig#"$HOME"/}"

  if rsi_dry; then
    rsi_dim "  would back up: $orig -> $backup"
    rsi_record backup "$orig" "$backup"
    return 0
  fi

  mkdir -p "$(dirname "$backup")"
  cp -a -- "$orig" "$backup"
  rsi_record backup "$orig" "$backup"
}
