#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: Google Lens search wiring"
}

lens_helper="bin/ryoku-cmd-google-lens"
region_qml="shell/modules/regionSelector/RegionSelection.qml"
selector_qml="shell/modules/regionSelector/RegionSelector.qml"
tool_registry="shell/modules/bar/threeIsland/dynamicIsland/tools/ToolRegistry.qml"

[[ -x $lens_helper ]] || fail "ryoku-cmd-google-lens should be executable"
bash -n "$lens_helper" || fail "ryoku-cmd-google-lens should be valid bash"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

printf 'probe\n' >"$tmpdir/image.png"
cat >"$tmpdir/ryoku-cmd-missing" <<'EOF'
#!/bin/bash
exit 1
EOF
cat >"$tmpdir/curl" <<'EOF'
#!/bin/bash
printf '{"files":[{"url":"https://example.com/probe.png"}]}'
EOF
cat >"$tmpdir/notify-send" <<'EOF'
#!/bin/bash
exit 0
EOF
cat >"$tmpdir/xdg-open" <<'EOF'
#!/bin/bash
printf '%s\n' "$1" >"$RYOKU_TEST_OPENED_URL"
EOF
chmod +x "$tmpdir/ryoku-cmd-missing" "$tmpdir/curl" "$tmpdir/notify-send" "$tmpdir/xdg-open"

opened_url="$tmpdir/opened-url"
PATH="$tmpdir:$PATH" RYOKU_TEST_OPENED_URL="$opened_url" "$lens_helper" --file "$tmpdir/image.png" \
  || fail "Google Lens helper should open a URL for a readable file"
actual_url="$(<"$opened_url")"
expected_url="https://www.google.com/searchbyimage?image_url=https%3A%2F%2Fexample.com%2Fprobe.png"
[[ $actual_url == $expected_url ]] \
  || fail "Google Lens helper should open the encoded searchbyimage URL"

grep -Fq -- 'https://www.google.com/searchbyimage?image_url=' "$lens_helper" \
  || fail "Google Lens helper should use the current Google searchbyimage endpoint"
if grep -Fq -- 'lens.google.com/uploadbyurl' "$lens_helper"; then
  fail "Google Lens helper should not use the old uploadbyurl endpoint"
fi

grep -Fq -- 'region", "googleLens"' "$tool_registry" \
  || fail "tools lens button should trigger the Google Lens IPC action"

grep -Fq -- "property bool googleLens" "$region_qml" \
  || fail "region selection should distinguish Google Lens from generic image search"
grep -Fq -- 'readonly property string googleLensSearchEngineBaseUrl: "https://www.google.com/searchbyimage?image_url="' "$region_qml" \
  || fail "region selection should use the current Google Lens endpoint"
grep -Fq -- 'return root.googleLensSearchEngineBaseUrl' "$region_qml" \
  || fail "region selection should route Google Lens requests to the Google endpoint"

grep -Fq -- "googleLens: root.googleLens" "$selector_qml" \
  || fail "region selector should pass Google Lens mode into the selection component"

if grep -Fq -- "-F \"fileToUpload=@'\${escaped}'\"" "$region_qml"; then
  fail "Catbox upload fallback should not include literal quotes in the curl filename"
fi
grep -Fq -- "-F fileToUpload=@'\${escaped}'" "$region_qml" \
  || fail "Catbox upload fallback should quote paths as shell syntax, not curl filename text"

pass
