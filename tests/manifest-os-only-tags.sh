#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# Every package the standalone shell install must never put on an existing
# system (bootloader/display-manager/kernel hooks the OS install owns) must
# live inside an `# @os-only` ... `# @end` region in one of the manifests.
# This replaces the old hardcoded RSI_ARCH_DENY list.
for pkg in sddm plymouth kernel-modules-hook limine-mkinitcpio-hook limine-snapper-sync; do
  found=0
  for m in install/ryoku-base.packages install/ryoku-aur.packages install/ryoku-other.packages; do
    if awk -v want="$pkg" '
      /^[[:space:]]*#[[:space:]]*@os-only/ { skip = 1; next }
      /^[[:space:]]*#[[:space:]]*@end/     { skip = 0; next }
      /^[[:space:]]*#/ { next }
      { gsub(/[[:space:]]/, "") }
      skip && $0 == want { print "HIT"; exit }
    ' "$ROOT_DIR/$m" | grep -q HIT; then
      found=1
      break
    fi
  done
  (( found == 1 )) || fail "$pkg must live inside an @os-only region"
done

printf 'PASS: tests/manifest-os-only-tags.sh\n'
