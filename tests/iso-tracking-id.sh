#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local file=$1 pattern=$2 message=$3
  rg -q -- "$pattern" "$ROOT_DIR/$file" || fail "$message"
}

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

iso="$tmp_dir/ryoku-2026.05.11-r99-deadbee-x86_64-main.iso"
sig="$iso.sig"
printf 'fake iso bytes\n' >"$iso"
printf 'fake signature bytes\n' >"$sig"

RYOKU_ISO_CHANNEL=stable \
RYOKU_ISO_TRACKING_ID=r99-deadbee \
RYOKU_ISO_COMMIT=deadbeefcafebabefeedface1234567890abcdef \
RYOKU_ISO_RUN_ID=123456 \
RYOKU_ISO_RUN_NUMBER=99 \
RYOKU_ISO_RUN_URL=https://github.com/neur0map/ryoku-arch/actions/runs/123456 \
RYOKU_ISO_PUBLIC_BASE=https://iso.ryoku.dev/stable \
  "$ROOT_DIR/iso/bin/ryoku-iso-manifest" "$iso"

manifest="$iso.json"
latest="$tmp_dir/latest.json"
manifest_js="$iso.js"
latest_js="$tmp_dir/latest.js"
[[ -f $manifest ]] || fail "per-ISO manifest should be written next to the ISO"
[[ -f $latest ]] || fail "latest.json should be written next to the ISO"
[[ -f $manifest_js ]] || fail "per-ISO script manifest should be written next to the ISO"
[[ -f $latest_js ]] || fail "latest.js should be written next to the ISO"
cmp -s "$manifest" "$latest" || fail "latest.json should match the per-ISO manifest"
cmp -s "$manifest_js" "$latest_js" || fail "latest.js should match the per-ISO script manifest"

iso_sha=$(sha256sum "$iso" | awk '{print $1}')
sig_sha=$(sha256sum "$sig" | awk '{print $1}')

rg -q '"tracking_id": "r99-deadbee"' "$manifest" || fail "manifest should include tracking_id"
rg -q '"iso": "ryoku-2026.05.11-r99-deadbee-x86_64-main.iso"' "$manifest" || fail "manifest should include tracked ISO filename"
rg -q '"url": "https://iso.ryoku.dev/stable/ryoku-2026.05.11-r99-deadbee-x86_64-main.iso"' "$manifest" || fail "manifest should include public ISO URL"
rg -q '"latest_script": "https://iso.ryoku.dev/stable/latest.js"' "$manifest" || fail "manifest should include latest.js URL"
rg -q "\"iso\": \"$iso_sha\"" "$manifest" || fail "manifest should include ISO sha256"
rg -q "\"signature\": \"$sig_sha\"" "$manifest" || fail "manifest should include signature sha256"

assert_contains '.github/workflows/build-iso.yml' 'RYOKU_ISO_TRACKING_ID' \
  "workflow should prepare a CI tracking ID"
assert_contains '.github/workflows/build-iso.yml' 'ryoku-iso-manifest' \
  "workflow should generate a release manifest"
assert_contains '.github/workflows/build-iso.yml' 'latest\.json' \
  "workflow should upload latest.json to R2"
assert_contains '.github/workflows/build-iso.yml' 'latest\.js' \
  "workflow should upload latest.js to R2 for the static website"
assert_contains 'iso/bin/ryoku-iso-make' 'RYOKU_ISO_TRACKING_ID' \
  "ryoku-iso-make should include tracking IDs in output names"
assert_contains 'iso/bin/ryoku-iso-make' 'SOURCE_DATE_EPOCH' \
  "ryoku-iso-make should pass a stable build timestamp into archiso"
assert_contains 'iso/builder/build-iso.sh' '/etc/ryoku-iso-release' \
  "ISO image should embed the tracking ID for support"

echo "PASS: tests/iso-tracking-id.sh"
