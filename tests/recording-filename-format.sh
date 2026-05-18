#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local path="$1"
  local needle="$2"

  grep -qF "$needle" "$path" || fail "$path should contain: $needle"
}

record_script="shell/scripts/videos/record.sh"

[[ -f $record_script ]] || fail "record script missing"
[[ $(head -n 1 "$record_script") == "#!/bin/bash" ]] || fail "record script should use repo bash shebang"
bash -n "$record_script" || fail "record script should parse"

assert_contains shell/defaults/config.json '"recordingNameFormat": "recording_%Y-%m-%d_%H.%M.%S"'
assert_contains shell/modules/common/Config.qml 'property string recordingNameFormat: "recording_%Y-%m-%d_%H.%M.%S"'
assert_contains "$record_script" "recording_output_base()"
assert_contains "$record_script" ".screenRecord.recordingNameFormat"
assert_contains shell/modules/settings/ToolsConfig.qml 'Config.setNestedValue("screenRecord.recordingNameFormat", text)'
assert_contains shell/modules/waffle/settings/pages/WInterfacePage.qml 'Config.setNestedValue("screenRecord.recordingNameFormat", newText)'

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/bin" "$tmpdir/config/ryoku-shell" "$tmpdir/videos"
cat >"$tmpdir/config/ryoku-shell/config.json" <<EOF
{
  "screenRecord": {
    "savePath": "$tmpdir/videos",
    "showNotifications": false,
    "enableFallback": false,
    "accelerationMode": "software",
    "recordingNameFormat": "clip %Y/%m/%d"
  }
}
EOF
cat >"$tmpdir/bin/pgrep" <<'EOF'
#!/bin/bash
exit 1
EOF
cat >"$tmpdir/bin/wf-recorder" <<'EOF'
#!/bin/bash
printf '%s\n' "$@" >"$RYOKU_TEST_RECORD_ARGS"
exit 0
EOF
chmod +x "$tmpdir/bin/pgrep" "$tmpdir/bin/wf-recorder"

RYOKU_TEST_RECORD_ARGS="$tmpdir/record.args" \
XDG_CONFIG_HOME="$tmpdir/config" \
PATH="$tmpdir/bin:$PATH" \
  "$record_script" --fullscreen

grep -qF "./clip " "$tmpdir/record.args" || fail "recording name should use configured date format"
grep -qF ".mp4" "$tmpdir/record.args" || fail "recording name should keep mp4 extension"
! grep -qF "/m/" "$tmpdir/record.args" || fail "recording name should not keep path separators from format output"

echo "PASS: recording filename format is configurable"
