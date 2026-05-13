#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local needle="$2"
  local message="$3"

  grep -Fq -- "$needle" "$file" || fail "$message"
}

helper="$ROOT_DIR/bin/ryoku-cmd-video-edit-ready"
[[ -x $helper ]] || fail "ryoku-cmd-video-edit-ready should be executable"
bash -n "$helper" || fail "ryoku-cmd-video-edit-ready should be valid bash"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin" "$tmp/Videos"
input="$tmp/Videos/recording with spaces.mp4"
touch "$input"

cat >"$tmp/bin/ffmpeg" <<'FFMPEG'
#!/bin/bash

printf '%s\n' "$*" > "$RYOKU_TEST_FFMPEG_ARGS"
touch "${@: -1}"
FFMPEG
chmod 755 "$tmp/bin/ffmpeg"

args="$tmp/ffmpeg-args"
output=$(
  PATH="$tmp/bin:$PATH" \
  RYOKU_TEST_FFMPEG_ARGS="$args" \
    "$helper" "$input"
)

expected_output="$tmp/Videos/EditReady/recording with spaces_edit.mov"
[[ $output == "$expected_output" ]] || fail "helper should print the generated edit-ready path"
[[ -f $expected_output ]] || fail "helper should create the default edit-ready output"

assert_contains "$args" "-map 0:v:0" "helper should transcode the first video stream"
assert_contains "$args" "-map 0:a:0?" "helper should keep optional audio"
assert_contains "$args" "-c:v prores_ks" "helper should use ProRes for editor compatibility"
assert_contains "$args" "-profile:v 0" "helper should use ProRes Proxy to keep output size lower"
assert_contains "$args" "-c:a pcm_s16le" "helper should use PCM audio for editor compatibility"
assert_contains "$args" "scale=trunc(iw/2)*2:trunc(ih/2)*2,format=yuv422p10le" \
  "helper should force editor-safe dimensions and pixel format"

custom_output="$tmp/custom/edit.mov"
PATH="$tmp/bin:$PATH" RYOKU_TEST_FFMPEG_ARGS="$args" "$helper" "$input" "$custom_output" >/dev/null
[[ -f $custom_output ]] || fail "helper should accept a custom output path"

echo "PASS: video edit-ready transcoder uses editor-compatible codecs"
