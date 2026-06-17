#!/usr/bin/env bash
# shellcheck shell=bash
# Install the base system with pacstrap, then write the fstab. The package set is
# system/packages/base.packages plus the per-profile section(s) of
# system/packages/hardware.packages (microcode + GPU drivers).

# read_section prints the package lines under [section] in an INI-style file,
# skipping comments and blank lines, stopping at the next [section].
read_section() {
  awk -v sec="[$2]" '
    $0 == sec { f = 1; next }
    /^\[/ { f = 0 }
    f && NF && $0 !~ /^[[:space:]]*#/ { print }
  ' "$1"
}

ryoku_pacstrap() {
  local base_file="$RYOKU_REPO/system/packages/base.packages"
  local hw_file="$RYOKU_REPO/system/packages/hardware.packages"
  [[ -f $base_file ]] || die "missing package list: $base_file"

  local -a pkgs=()
  mapfile -t pkgs < <(grep -vE '^[[:space:]]*(#|$)' "$base_file")

  local -a sections=()
  case "$RYOKU_PROFILE" in
    amd) sections=(amd) ;;
    intel) sections=(intel) ;;
    amd-nvidia) sections=(amd nvidia) ;;
    vm) sections=(vm) ;;
    *) die "unknown RYOKU_PROFILE: $RYOKU_PROFILE (want amd-nvidia|amd|intel|vm)" ;;
  esac

  local -a hw=()
  local sec
  for sec in "${sections[@]}"; do
    [[ -f $hw_file ]] && mapfile -t -O "${#hw[@]}" hw < <(read_section "$hw_file" "$sec")
  done
  (( ${#hw[@]} )) && pkgs+=("${hw[@]}")

  log "installing ${#pkgs[@]} packages (profile=$RYOKU_PROFILE)"
  run pacstrap -K /mnt "${pkgs[@]}"

  log "writing /etc/fstab"
  run_sh "genfstab -U /mnt >> /mnt/etc/fstab"
}
