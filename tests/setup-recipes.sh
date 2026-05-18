#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"

  [[ -f $path ]] || fail "$path should exist"
}

assert_executable() {
  local path="$1"

  assert_file "$path"
  [[ -x $path ]] || fail "$path should be executable"
}

assert_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq "$pattern" "$path" || fail "$message"
}

assert_not_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  if grep -Eq "$pattern" "$path"; then
    fail "$message"
  fi
}

assert_executable "shell/scripts/setup/_scan.sh"
assert_file "shell/scripts/setup/_lib.sh"
assert_executable "shell/scripts/setup/spotify.sh"
assert_file "shell/scripts/setup/README.md"
assert_file "shell/scripts/setup/_template.sh.example"

bash -n shell/scripts/setup/_scan.sh
bash -n shell/scripts/setup/_lib.sh
bash -n shell/scripts/setup/spotify.sh

scan_json="$(bash shell/scripts/setup/_scan.sh)"
jq -e '
  length == 1
  and .[0].slug == "spotify"
  and .[0].name == "Setup Spotify + Spicetify"
  and (.[0].keywords | contains("spotify"))
' <<<"$scan_json" >/dev/null || fail "setup scanner should expose spotify recipe metadata"

assert_contains "shell/defaults/config.json" '"enableSetup": true' \
  "default config should enable setup global actions"
assert_contains "shell/modules/common/Config.qml" 'property bool enableSetup: true' \
  "Config.qml should expose enableSetup"
assert_contains "shell/services/GlobalActions.qml" '"setup".*"custom"|"custom".*"setup"' \
  "GlobalActions categories should include setup"
assert_contains "shell/services/GlobalActions.qml" '_setupActions' \
  "GlobalActions should build setup actions"
assert_contains "shell/services/GlobalActions.qml" 'scriptsPath.*/setup/_scan\.sh' \
  "GlobalActions should scan scripts/setup recipes"
assert_contains "shell/services/GlobalActions.qml" 'cfg\?\.enableSetup \?\? true' \
  "GlobalActions should respect enableSetup"

assert_contains "shell/scripts/setup/spotify.sh" 'ryoku' \
  "spotify setup recipe should use Ryoku naming"
upstream_shell='i''nir'
upstream_brand='iN''iR'
upstream_config='illogical''-impulse'
upstream_org='snow''arch'
assert_not_contains "shell/scripts/setup/spotify.sh" "$upstream_brand|$upstream_shell|$upstream_config|$upstream_org" \
  "spotify setup recipe should not ship upstream product names"
assert_contains "shell/scripts/setup/spotify.sh" 'enableSpicetify' \
  "spotify setup recipe should honor the Spicetify theme toggle"

assert_contains "shell/scripts/colors/apply-spicetify-theme.sh" 'apply_spicetify_theme' \
  "Spicetify theme script should call apply when watch mode is inactive"
assert_contains "shell/scripts/colors/apply-spicetify-theme.sh" 'Spotify not running - theme applied to bundle for next launch' \
  "Spicetify theme script should patch the bundle even when Spotify is closed"

echo "PASS: setup recipes framework"
