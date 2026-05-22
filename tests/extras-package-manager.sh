#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
EXTRAS_QML="$ROOT_DIR/shell/modules/settings/ExtrasConfig.qml"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[[ -f $EXTRAS_QML ]] || fail "missing ExtrasConfig.qml"

open_gpk_count="$(rg -c 'mainText: Translation\.tr\("Open GPK"\)' "$EXTRAS_QML")"
(( open_gpk_count == 1 )) || fail "Package manager section should expose exactly one Open GPK button"

launch_gpk_count="$(rg -c 'onClicked: root\.launchGpk\(\)' "$EXTRAS_QML")"
(( launch_gpk_count == 1 )) || fail "Only one button should launch GPK directly"

! rg -q 'launchGpkPrompt|launchGpkOutdated' "$EXTRAS_QML" || \
  fail "Package manager section should not expose separate GPK prompt/outdated launchers"

! rg -q 'mainText: Translation\.tr\("(Install package|Uninstall package|Update package|Outdated)"\)' "$EXTRAS_QML" || \
  fail "Package manager section should not duplicate GPK subcommands as separate buttons"

rg -q 'Search Arch repos' "$EXTRAS_QML" || \
  fail "Package manager section should keep the Arch package picker"

rg -q 'Search AUR' "$EXTRAS_QML" || \
  fail "Package manager section should keep the AUR package picker"

echo "PASS: Extras package manager card has one GPK launcher"
