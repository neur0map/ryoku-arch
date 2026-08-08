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
# pacstrap. pacman-init.service is a oneshot that builds it at boot, so we block
# on `systemctl start` (returns only once it has finished, or immediately if it
# already ran), then populate if the keyring is still empty. without this,
# pacstrap fails to verify packages (public keyring not found / failed to
# install packages to new root).
ryoku_ensure_keyring() {
  # a oneshot's `start` blocks until it has finished, so this can't race the
  # service to pacstrap the way the old is-active poll did. failure is fine: the
  # populate fallback below still covers a keyring that never got built.
  run_sh 'systemctl start pacman-init.service 2>/dev/null || true'
  [[ -n "$(pacman-key --list-keys 2>/dev/null)" ]] && return 0
  log "initializing the pacman keyring"
  run pacman-key --init
  run pacman-key --populate archlinux
  # verify the rebuild produced keys; otherwise pacstrap dies later with a
  # cryptic "invalid or corrupted package (PGP signature)" AFTER the disk wipe.
  # fail here instead. (dry-run never really inits, so skip the check.)
  [[ -n ${RYOKU_DRYRUN:-} ]] && return 0
  [[ -n "$(pacman-key --list-keys 2>/dev/null)" ]] || \
    die "the pacman keyring is still empty after init + populate; package signatures cannot be verified. The live image's archlinux-keyring is broken; re-download or rewrite the ISO."
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
    amd-nvidia) sections=(amd intel nvidia) ;;
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

  # Broadcom wifi (BCM43xx) needs the out-of-tree broadcom-wl driver; the
  # in-kernel b43/brcmsmac often can't associate. add it only when a Broadcom
  # network controller (PCI vendor 14e4) is present. guard lspci's absence.
  if command -v lspci >/dev/null 2>&1 && [[ -n "$(lspci -d 14e4: 2>/dev/null)" ]]; then
    log "detected a Broadcom device (14e4:*); adding broadcom-wl to the pacstrap set"
    pkgs+=(broadcom-wl)
  fi

  ryoku_ensure_keyring
  log "installing ${#pkgs[@]} packages (profile=$RYOKU_PROFILE)"
  ryoku_pacstrap_install "${pkgs[@]}"

  log "writing /etc/fstab"
  run_sh "genfstab -U /mnt >> /mnt/etc/fstab"
}

# install the package set, retrying once from the NEXT mirror tier on failure.
# a wifi drop, a slow mirror, or a package that downloaded corrupt otherwise
# kills the install with raw pacman errors. the retry drops the poisoned cache
# (a bad-signature package makes non-interactive pacstrap fail identically on the
# reused cache), regenerates the mirrorlist from a different source, and adds
# --needed so it resumes over the already-installed packages (issue #21) instead
# of redoing the whole set. separated from ryoku_pacstrap so the retry path is
# testable with stubs.
ryoku_pacstrap_install() {
  local -a pkgs=("$@")
  if run pacstrap -K /mnt "${pkgs[@]}"; then
    return 0
  fi

  log "pacstrap failed (connection drop, slow mirror, or a package corrupt under load); clearing the target cache, dropping to the next mirror tier, and retrying once with --needed"
  run_sh 'rm -f /mnt/var/cache/pacman/pkg/*.pkg.tar.* 2>/dev/null || true'
  ryoku_mirrors_fallback || true

  local paclog
  paclog=$(mktemp) || paclog=/dev/null
  if run pacstrap -K --needed /mnt "${pkgs[@]}" >"$paclog" 2>&1; then
    [[ $paclog == /dev/null ]] || { cat -- "$paclog"; rm -f -- "$paclog"; }
    return 0
  fi

  [[ $paclog == /dev/null ]] || cat -- "$paclog"
  local failinfo=""
  [[ $paclog == /dev/null ]] \
    || failinfo=$(grep -aoE "failed retrieving file '?[^' ]+'? from [^ ]+" "$paclog" 2>/dev/null | tail -n1) || failinfo=""
  rm -f -- "$paclog" 2>/dev/null || true
  die "pacstrap failed after retrying across mirror tiers (tried: ${RYOKU_MIRROR_TIERS_TRIED:-tier 1 (reflector)}).${failinfo:+ Last mirror error: $failinfo.} Check the connection (Wi-Fi can drop under sustained download) and re-run the installer."
}
