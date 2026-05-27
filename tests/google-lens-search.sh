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
island_qml="shell/modules/island/Content.qml"

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
[[ $actual_url == "https://www.google.com/searchbyimage?image_url=https%3A%2F%2Fexample.com%2Fprobe.png" ]] \
  || fail "Google Lens helper should open the encoded searchbyimage URL"

grep -Fq -- 'https://www.google.com/searchbyimage?image_url=' "$lens_helper" \
  || fail "Google Lens helper should use the current Google searchbyimage endpoint"
if grep -Fq -- 'lens.google.com/uploadbyurl' "$lens_helper"; then
  fail "Google Lens helper should not use the old uploadbyurl endpoint"
fi

grep -Fq -- '["ryoku-cmd-google-lens"]' "$island_qml" \
  || fail "dynamic island Lens button should trigger the Google Lens helper"

pass
