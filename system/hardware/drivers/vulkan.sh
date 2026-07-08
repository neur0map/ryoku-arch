#!/usr/bin/env bash
#
# vulkan.sh: install the Vulkan ICD loader.
#
# vulkan-icd-loader = the vendor-neutral loader every Vulkan app links to.
# dispatches to whichever ICD the vendor driver dropped in (vulkan-radeon,
# vulkan-intel, nvidia-utils). amd/intel/nvidia.sh handle the ICDs; this
# script only guarantees the loader is around.
#
# idempotent, gated on >=1 GPU, dry-run via RYOKU_DRYRUN.

set -euo pipefail

RYOKU_DRYRUN="${RYOKU_DRYRUN:-0}"
for arg in "$@"; do
  case "$arg" in
    --dry-run) RYOKU_DRYRUN=1 ;;
    -h | --help)
      echo "Usage: vulkan.sh [--dry-run]"
      echo "Install the vulkan-icd-loader (the loader every Vulkan driver needs)."
      exit 0
      ;;
    *)
      echo "vulkan.sh: unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

run() {
  if [[ $RYOKU_DRYRUN == 1 ]]; then
    printf 'DRYRUN: %s\n' "$*"
    return 0
  fi
  "$@"
}

PM=(pacman)
(( EUID == 0 )) || PM=(sudo -n pacman)

pkg_installed() { pacman -Qq "$1" >/dev/null 2>&1; }

install_pkgs() {
  local missing=() p
  for p in "$@"; do pkg_installed "$p" || missing+=("$p"); done
  if (( ${#missing[@]} == 0 )); then
    echo "vulkan.sh: already installed: $*"
    return 0
  fi
  echo "vulkan.sh: installing ${missing[*]}"
  run "${PM[@]}" -S --needed --noconfirm "${missing[@]}"
}

has_any_gpu() {
  compgen -G '/sys/class/drm/card[0-9]*' >/dev/null
}

if ! has_any_gpu; then
  echo "vulkan.sh: no GPU detected, nothing to do."
  exit 0
fi

install_pkgs vulkan-icd-loader
