#!/usr/bin/env bash
# Verify the shipped WirePlumber fragment changes the effective session policy,
# rather than merely being syntactically present in the repository.
set -euo pipefail

ROOT=${RYOKU_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
if ! command -v pw-config >/dev/null 2>&1; then
  printf 'SKIP: pw-config is unavailable\n'
  exit 0
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/wireplumber/wireplumber.conf.d"
cp /usr/share/wireplumber/wireplumber.conf "$work/wireplumber/"
cp "$ROOT/ryoku/apps/wireplumber/wireplumber.conf.d/51-ryoku-bluetooth.conf" \
  "$work/wireplumber/wireplumber.conf.d/"

merged=$(PIPEWIRE_CONFIG_DIR="$work/wireplumber" pw-config -N -n wireplumber.conf merge wireplumber.settings)
if [[ $merged != *'"bluetooth.autoswitch-to-headset-profile": false'* ]]; then
  printf 'FAIL: effective WirePlumber policy still allows automatic A2DP -> headset switching\n%s\n' "$merged" >&2
  exit 1
fi

printf 'PASS: Bluetooth playback remains on A2DP until the user selects headset mode\n'
