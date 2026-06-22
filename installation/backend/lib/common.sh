#!/usr/bin/env bash
# Shared helpers for ryoku-install: logging, the dry-run command wrapper, and a
# few small utilities the step libraries lean on. Sourced, never run directly.

# log writes a progress line to stdout. The TUI streams these into its scroll view.
log() { printf '  %s\n' "$*"; }

# step prints a staged-progress sentinel the TUI watches for. ids in order:
# partition, filesystems, mount, pacstrap, configure, bootloader.
step() { printf '@@RYOKU_STEP %s\n' "$1"; }

# die aborts the install with a message on stderr and a non-zero exit.
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# run executes a destructive/system command, or prints it (prefixed DRYRUN:)
# when RYOKU_DRYRUN is set. Use for plain argv commands with no shell features.
run() {
  if [[ -n ${RYOKU_DRYRUN:-} ]]; then
    printf 'DRYRUN: %s\n' "$*"
    return 0
  fi
  "$@"
}

# run_sh is run() for commands that need shell features (pipes, redirects).
# Pass a single string; it is printed verbatim under dry-run, else run via bash.
run_sh() {
  if [[ -n ${RYOKU_DRYRUN:-} ]]; then
    printf 'DRYRUN: %s\n' "$1"
    return 0
  fi
  bash -c "$1"
}

# run_secret runs a command that reads a secret on stdin, redacting it under
# dry-run. Args: <label-for-dryrun> <command> [args...]; the secret is on stdin.
run_secret() {
  local label=$1; shift
  if [[ -n ${RYOKU_DRYRUN:-} ]]; then
    cat >/dev/null 2>&1 || true
    printf 'DRYRUN: %s\n' "$label"
    return 0
  fi
  "$@"
}

# write_file writes stdin to a path. Under dry-run it prints the target and the
# content instead of touching the filesystem. Parent dirs are not created here.
write_file() {
  local path=$1 content
  content=$(cat)
  if [[ -n ${RYOKU_DRYRUN:-} ]]; then
    printf 'DRYRUN: write %s:\n' "$path"
    printf '%s\n' "$content" | sed 's/^/        | /'
    return 0
  fi
  printf '%s\n' "$content" >"$path"
}

# append_file appends stdin to a path. Under dry-run it prints the target and the
# content instead of touching the filesystem. Parent dirs are not created here.
append_file() {
  local path=$1 content
  content=$(cat)
  if [[ -n ${RYOKU_DRYRUN:-} ]]; then
    printf 'DRYRUN: append %s:\n' "$path"
    printf '%s\n' "$content" | sed 's/^/        | /'
    return 0
  fi
  printf '%s\n' "$content" >>"$path"
}

# deploy_dir copies a source tree into a destination (dir-as-dir contents).
# Missing sources are skipped with a note in real mode; under dry-run the
# intended copy is always printed.
deploy_dir() {
  local src=$1 dst=$2
  if [[ -n ${RYOKU_DRYRUN:-} ]]; then
    printf 'DRYRUN: mkdir -p %s && cp -rT %s %s\n' "$dst" "$src" "$dst"
    return 0
  fi
  [[ -d $src ]] || { log "skip: $src not present"; return 0; }
  mkdir -p "$dst"
  cp -rT "$src" "$dst"
}

# part_dev returns the Nth partition device for a disk, handling the nvme/mmc
# 'p' separator (nvme0n1 -> nvme0n1p2) vs plain disks (vda -> vda2).
part_dev() {
  local disk=$1 num=$2
  if [[ $disk == *[0-9] ]]; then
    printf '%sp%s' "$disk" "$num"
  else
    printf '%s%s' "$disk" "$num"
  fi
}

# part_num returns the trailing partition number of a partition device
# (nvme0n1p2 -> 2, sda2 -> 2, mmcblk0p1 -> 1). Inverse of part_dev, used to
# register the right ESP partition with efibootmgr when its number is not 1.
part_num() {
  [[ $1 =~ ([0-9]+)$ ]] && printf '%s' "${BASH_REMATCH[1]}"
}

# dev_uuid prints the UUID of a block device. Under dry-run the device does not
# exist, so a readable placeholder is returned in its place.
dev_uuid() {
  if [[ -n ${RYOKU_DRYRUN:-} ]]; then
    printf '<UUID:%s>' "$1"
    return 0
  fi
  blkid -s UUID -o value "$1"
}
