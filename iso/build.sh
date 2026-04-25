#!/bin/bash
#
# Build the Ryoku Arch ISO via mkarchiso.
#
# Usage: sudo bash iso/build.sh
#
# Output: iso/out/ryoku-arch-<date>-x86_64.iso

set -eEo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "iso/build.sh requires root: re-run with 'sudo bash iso/build.sh'" >&2
  exit 1
fi

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE_DIR="$REPO_ROOT/iso/releng-ryoku"
WORK_DIR="${RYOKU_ISO_WORK:-/tmp/ryoku-iso-work}"
OUT_DIR="${RYOKU_ISO_OUT:-$REPO_ROOT/iso/out}"

if [[ ! -d $PROFILE_DIR ]]; then
  echo "missing profile directory: $PROFILE_DIR" >&2
  exit 1
fi

if ! command -v mkarchiso >/dev/null 2>&1; then
  echo "mkarchiso not found. Install with: pacman -S archiso" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

echo "Building Ryoku Arch ISO."
echo "  profile: $PROFILE_DIR"
echo "  work:    $WORK_DIR"
echo "  output:  $OUT_DIR"
echo

mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"

echo
echo "Build complete. Outputs:"
ls -lh "$OUT_DIR"
