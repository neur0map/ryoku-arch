#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
RYOKU="$ROOT_DIR/shell/scripts/ryoku"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq "$pattern" "$ROOT_DIR/$path" || fail "$message"
}

[[ -x $RYOKU ]] || fail "ryoku compatibility helper should be executable"
bash -n "$RYOKU" || fail "ryoku compatibility helper should be valid bash"

command -v jq >/dev/null 2>&1 || fail "jq is required for appearance bridge tests"

assert_contains shell/services/Colours.qml 'Scheme parse failed' \
  "Colours service should ignore partial scheme writes instead of crashing on JSON.parse"
assert_contains shell/modules/launcher/services/Schemes.qml 'Scheme list parse failed' \
  "Schemes service should handle invalid scheme-list output"
assert_contains shell/modules/controlcenter/appearance/AppearancePane.qml 'resolveFont' \
  "Appearance settings should resolve saved fonts to installed families"
assert_contains shell/modules/controlcenter/appearance/sections/FontsSection.qml 'fontModel' \
  "Fonts settings should keep current and recommended fonts visible"
assert_contains shell/utils/SysInfo.qml 'GlobalConfig\.general\.logo \|\| "ryoku"' \
  "shell should default to the Ryoku logo when no custom logo is configured"
assert_contains shell/plugin/src/Ryoku/Config/generalconfig.hpp 'CONFIG_GLOBAL_PROPERTY\(QString, logo, u"ryoku"_s\)' \
  "native config defaults should expose Ryoku as the default shell logo"
[[ -f $ROOT_DIR/shell/assets/logo.png ]] || fail "shell should ship a raster Ryoku logo asset for compact bar rendering"
assert_contains shell/components/Logo.qml 'assets/logo\.png' \
  "default shell logo component should render the raster Ryoku kanji asset"
assert_contains shell/assets/logo.svg 'viewBox="-72 -72 656 656"' \
  "Ryoku shell logo asset should include enough viewBox padding to avoid clipping"
assert_contains assets/brand/logo-mark.svg 'viewBox="-72 -72 656 656"' \
  "canonical transparent Ryoku mark should include enough viewBox padding to avoid clipping"
assert_contains shell/modules/bar/components/OsIcon.qml 'implicitWidth: logoSize' \
  "bar logo container should allocate the full Ryoku logo width"
assert_contains shell/modules/bar/components/OsIcon.qml 'implicitHeight: logoSize' \
  "bar logo container should allocate the full Ryoku logo height"
assert_contains shell/modules/bar/Bar.qml 'roleValue: "logo"' \
  "bar defaults should include the logo module"
assert_contains shell/modules/bar/components/workspaces/Workspace.qml 'resolveWorkspaceLabel' \
  "workspace labels should normalize legacy glyph defaults"
assert_contains shell/modules/bar/components/workspaces/Workspace.qml 'Colours\.palette\.m3onSurfaceVariant' \
  "inactive workspace labels should use readable surface-variant contrast"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
test_home="$tmp_dir/home"
state_home="$tmp_dir/state"
mkdir -p "$test_home" "$state_home"

run_ryoku() {
  HOME="$test_home" XDG_STATE_HOME="$state_home" "$RYOKU" "$@"
}

run_ryoku scheme set -m light -v tonalspot -f default
scheme_file="$state_home/ryoku-shell/scheme.json"

jq -e '.mode == "light" and .variant == "tonalspot" and .flavour == "default"' "$scheme_file" >/dev/null || \
  fail "scheme set should persist mode, variant, and flavour"
jq -e '.colours.background == "FCF8F6" and .colours.onBackground == "1F1B18" and .colours.surface != "171717"' "$scheme_file" >/dev/null || \
  fail "light mode should write a real light palette"

light_primary=$(jq -r '.colours.primary' "$scheme_file")

run_ryoku scheme set -m dark
jq -e '.mode == "dark" and .colours.background == "171717" and .colours.onBackground == "CCD0CF"' "$scheme_file" >/dev/null || \
  fail "dark mode should write a dark palette"

run_ryoku scheme set -m light -v monochrome
mono_primary=$(jq -r '.colours.primary' "$scheme_file")
run_ryoku scheme set -m light -v vibrant
vibrant_primary=$(jq -r '.colours.primary' "$scheme_file")

[[ $mono_primary != "$vibrant_primary" ]] || \
  fail "color variants should produce visibly different palettes"
[[ $light_primary != "$vibrant_primary" ]] || \
  fail "vibrant variant should differ from tonal spot"

list_json=$(run_ryoku scheme list)
jq -e '.ryoku | length >= 6' <<<"$list_json" >/dev/null || \
  fail "scheme list should expose more than one selectable color scheme"
jq -e '.ryoku | keys | index("forest") and index("ocean") and index("amethyst")' <<<"$list_json" >/dev/null || \
  fail "scheme list should include the Ryoku palette flavours"
jq -e 'all(.ryoku[]; .surface and .primary and .onSurface)' <<<"$list_json" >/dev/null || \
  fail "scheme list entries should include preview colors"

run_ryoku scheme set -n ryoku -f ocean -v neutral -m dark
mapfile -t current < <(run_ryoku scheme get -nfv)
[[ ${current[0]} == "ryoku" && ${current[1]} == "ocean" && ${current[2]} == "neutral" ]] || \
  fail "scheme get -nfv should return current name, flavour, and variant"

echo "PASS: rebirth shell appearance bridge exposes working modes, variants, schemes, and font fallbacks"
