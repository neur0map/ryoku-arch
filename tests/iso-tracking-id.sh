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

line_number() {
  local file=$1 pattern=$2
  rg -n -- "$pattern" "$ROOT_DIR/$file" 2>/dev/null | awk -F: 'NR == 1 { print $1 }' || true
}

assert_order() {
  local file=$1 first=$2 second=$3 message=$4
  local first_line second_line
  first_line=$(line_number "$file" "$first")
  second_line=$(line_number "$file" "$second")

  [[ -n $first_line ]] || fail "missing expected workflow step: $first"
  [[ -n $second_line ]] || fail "missing expected workflow step: $second"
  (( first_line < second_line )) || fail "$message"
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
rg -q '"channel": "stable"' "$manifest" || fail "manifest should include public release channel"
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
assert_contains '.github/workflows/build-iso.yml' 'PUBLIC_CHANNEL: stable' \
  "workflow should publish public ISO metadata under the stable R2 prefix"
assert_contains '.github/workflows/build-iso.yml' 'RYOKU_ISO_CHANNEL=\$PUBLIC_CHANNEL' \
  "workflow should write stable as the public manifest channel"
assert_contains '.github/workflows/build-iso.yml' 'RYOKU_ISO_PUBLIC_BASE="https://iso\.ryoku\.dev/\$\{PUBLIC_CHANNEL\}"' \
  "workflow should generate public ISO URLs under the stable R2 prefix"
assert_contains '.github/workflows/build-iso.yml' 'latest_url="https://iso\.ryoku\.dev/\$\{PUBLIC_CHANNEL\}/latest\.json"' \
  "workflow should read previous release metadata from the stable R2 prefix"
assert_contains '.github/workflows/build-iso.yml' 'dest="\$\{R2_BUCKET:-ryoku/\$PUBLIC_CHANNEL\}"' \
  "workflow should upload ISO artifacts to the stable R2 prefix by default"
assert_contains '.github/workflows/build-iso.yml' 'security-events: write' \
  "workflow should be able to upload ISO Trivy SARIF to code scanning"
assert_contains '.github/workflows/build-iso.yml' 'Mount ISO live root for Trivy' \
  "workflow should mount the built ISO root filesystem before release"
assert_contains '.github/workflows/build-iso.yml' 'RYOKU_TRIVY_ROOTFS_MOUNT=\$rootfs_mount' \
  "workflow should keep the read-only SquashFS mount separate from the Trivy scan tree"
assert_contains '.github/workflows/build-iso.yml' 'RYOKU_TRIVY_ROOTFS=\$rootfs_scan' \
  "workflow should point Trivy at a readable rootfs copy"
assert_contains '.github/workflows/build-iso.yml' 'sudo rsync -aH --numeric-ids "\$rootfs_mount/" "\$rootfs_scan/"' \
  "workflow should copy the mounted live root before scanning"
assert_contains '.github/workflows/build-iso.yml' 'sudo chmod -R u\+rwX,go\+rX "\$rootfs_scan"' \
  "workflow should make the Trivy scan copy readable to the non-root action process"
assert_contains 'iso/builder/build-iso.sh' 'build-gum-package\.sh' \
  "ISO builder should rebuild gum with the current Go toolchain before scanning"
assert_contains 'iso/builder/build-iso.sh' 'rebuilt_official_packages=\(gum\)' \
  "ISO builder should avoid downloading the stale official gum package"
assert_contains 'iso/builder/build-gum-package.sh' 'CVE-2025-68121' \
  "gum rebuild script should document the Trivy blocker it fixes"
assert_contains 'iso/builder/build-gum-package.sh' 'http\.version=HTTP/1\.1' \
  "gum rebuild script should use the hardened git transport"
assert_contains 'iso/builder/build-gum-package.sh' 'sudo -u builder git -C "\$src_dir" rev-parse HEAD' \
  "gum rebuild script should read git metadata with matching repository ownership"
assert_contains 'iso/builder/build-gum-package.sh' 'go build' \
  "gum rebuild script should compile gum from source"
assert_contains 'iso/builder/build-gum-package.sh' 'pushd "\$pkgbuild_dir"' \
  "gum rebuild script should run makepkg from the generated PKGBUILD directory"
assert_contains '.github/workflows/build-iso.yml' 'scan-type: rootfs' \
  "workflow should scan the built live root filesystem, not just source files"
assert_contains '.github/workflows/build-iso.yml' 'trivy-iso-results\.sarif' \
  "workflow should upload an ISO Trivy SARIF report"
assert_contains '.github/workflows/build-iso.yml' 'version: v0\.70\.0' \
  "workflow should pin the Trivy CLI version used for ISO scans"
assert_contains '.github/workflows/build-iso.yml' 'Block ISO critical CVEs and misconfigurations' \
  "workflow should block publishing when the built ISO has critical findings"
assert_order '.github/workflows/build-iso.yml' 'Generate ISO Trivy SARIF report' \
  'Block ISO critical CVEs and misconfigurations' \
  "workflow should generate the ISO Trivy report before enforcing the gate"
assert_order '.github/workflows/build-iso.yml' 'Block ISO critical CVEs and misconfigurations' \
  'Sign ISO with GPG' \
  "workflow should scan and gate the ISO before signing it"
assert_order '.github/workflows/build-iso.yml' 'Block ISO critical CVEs and misconfigurations' \
  'Upload to Cloudflare R2' \
  "workflow should scan and gate the ISO before publishing it"
assert_contains 'iso/bin/ryoku-iso-make' 'RYOKU_ISO_TRACKING_ID' \
  "ryoku-iso-make should include tracking IDs in output names"
assert_contains 'iso/bin/ryoku-iso-make' 'SOURCE_DATE_EPOCH' \
  "ryoku-iso-make should pass a stable build timestamp into archiso"
assert_contains 'iso/builder/build-iso.sh' '/etc/ryoku-iso-release' \
  "ISO image should embed the tracking ID for support"

echo "PASS: tests/iso-tracking-id.sh"
