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

assert_not_contains() {
  local file=$1 pattern=$2 message=$3

  if rg -q -- "$pattern" "$ROOT_DIR/$file"; then
    fail "$message"
  fi
}

assert_contains "shell/defaults/plugins/music/scripts/sponsorblock.js" "normalizeVideoId" \
  "SponsorBlock should validate video IDs before API use"
assert_contains "shell/defaults/plugins/music/scripts/sponsorblock.js" "encodeURIComponent\\(videoId\\)" \
  "SponsorBlock should encode video IDs in API URLs"
assert_contains "shell/defaults/plugins/music/scripts/sponsorblock.js" "safeSegmentCategory" \
  "SponsorBlock should normalize external category values before display"
assert_contains "shell/defaults/plugins/music/scripts/sponsorblock.js" "div\\.textContent" \
  "SponsorBlock notification should render text, not HTML"
assert_not_contains "shell/defaults/plugins/music/scripts/sponsorblock.js" "innerHTML|insertAdjacentHTML|outerHTML" \
  "SponsorBlock should not use HTML injection APIs"

assert_contains "shell/defaults/plugins/discord/scripts/session-persist.js" "isDiscordHost" \
  "Discord session script should use an explicit host allowlist"
assert_not_contains "shell/defaults/plugins/discord/scripts/session-persist.js" "hostname\\.includes\\('discord'\\)" \
  "Discord session script should not match arbitrary hostnames containing discord"

assert_contains "shell/scripts/scan-plugins.py" "def safe_plugin_path" \
  "Plugin scanner should constrain manifest paths to the plugin directory"
assert_contains "shell/scripts/scan-plugins.py" "os\\.path\\.realpath" \
  "Plugin scanner should resolve paths before checking containment"
assert_contains "shell/scripts/scan-plugins.py" "MAX_USERSCRIPT_BYTES" \
  "Plugin scanner should cap userscript size before injecting into WebEngine"
assert_contains "shell/scripts/scan-plugins.py" "\\.endswith\\(\"\\.js\"\\)" \
  "Plugin scanner should only read JavaScript userscripts"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

plugin_dir="$tmp_dir/ryoku-shell/plugins/path-test"
mkdir -p "$plugin_dir"
printf 'alert("SAFE");\n' > "$plugin_dir/safe.js"
printf 'alert("TEXT");\n' > "$plugin_dir/not.txt"
printf 'alert("SECRET");\n' > "$tmp_dir/ryoku-shell/secret.js"
printf 'fake image\n' > "$tmp_dir/ryoku-shell/secret.png"
cat > "$plugin_dir/manifest.json" <<'JSON'
{
  "id": "path-test",
  "url": "https://example.test",
  "iconPath": "../../secret.png",
  "userscripts": [
    "safe.js",
    "../../secret.js",
    "not.txt"
  ]
}
JSON

scan_output=$(XDG_CONFIG_HOME="$tmp_dir" "$ROOT_DIR/shell/scripts/scan-plugins.py")
[[ $scan_output == *SAFE* ]] || fail "Plugin scanner should include safe in-plugin userscripts"
[[ $scan_output != *SECRET* ]] || fail "Plugin scanner should reject userscript path traversal"
[[ $scan_output != *TEXT* ]] || fail "Plugin scanner should reject non-JavaScript userscripts"
[[ $scan_output != *secret.png* ]] || fail "Plugin scanner should reject icon path traversal"

echo "PASS: webapp plugin security"
