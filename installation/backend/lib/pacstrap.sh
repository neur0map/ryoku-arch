#!/usr/bin/env bash
# shellcheck shell=bash
# Install the base system with pacstrap, then write fstab. package set =
# system/packages/base.packages + the per-profile section(s) of
# system/packages/hardware.packages (microcode + GPU drivers) + the developer
# toolchains in system/packages/dev.packages.

# read_section: prints the package lines under [section] in an INI-style file,
# skipping comments + blanks, stops at the next [section].
read_section() {
  awk -v sec="[$2]" '
    $0 == sec { f = 1; next }
    /^\[/ { f = 0 }
    f && NF && $0 !~ /^[[:space:]]*#/ { print }
  ' "$1"
}

# ryoku_ensure_keyring: make sure the live pacman keyring is ready before
# pacstrap. pacman-init.service builds it at boot but can still be running (or
# missing) when the user hits the install step, so wait for it to settle, then
# populate if the keyring is still empty. without this, pacstrap fails to verify
# packages (public keyring not found / failed to install packages to new root).
ryoku_ensure_keyring() {
  for _ in $(seq 1 60); do
    [[ "$(systemctl is-active pacman-init.service 2>/dev/null)" == activating ]] || break
    sleep 1
  done
  [[ -n "$(pacman-key --list-keys 2>/dev/null)" ]] && return 0
  log "initializing the pacman keyring"
  run pacman-key --init
  run pacman-key --populate archlinux
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

  # dev toolchains ship with every machine (Go, Node/npm, Rust, Python, mise).
  local dev_file="$RYOKU_REPO/system/packages/dev.packages"
  local -a dev=()
  [[ -f $dev_file ]] && mapfile -t dev < <(grep -vE '^[[:space:]]*(#|$)' "$dev_file")
  (( ${#dev[@]} )) && pkgs+=("${dev[@]}")

  ryoku_ensure_keyring
  log "installing ${#pkgs[@]} packages (profile=$RYOKU_PROFILE)"
  # one retry: a wifi drop mid-download otherwise kills the install with raw
  # pacman errors; the second run reuses everything already in the target cache.
  if ! run pacstrap -K /mnt "${pkgs[@]}"; then
    log "pacstrap failed (usually the connection dropping under load); retrying once"
    run pacstrap -K /mnt "${pkgs[@]}" \
      || die "pacstrap failed twice. Check the network (Wi-Fi can drop under sustained download) and re-run the installer; packages already fetched are cached on the target and will not download again."
  fi

  log "writing /etc/fstab"
  run_sh "genfstab -U /mnt >> /mnt/etc/fstab"
}
