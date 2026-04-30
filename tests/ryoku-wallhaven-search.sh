#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

script="bin/ryoku-wallhaven-search"
[[ -x $script ]] || fail "ryoku-wallhaven-search should be executable"

url=$("$script" search --query "samurai city #1" --page 2 --print-url)
case "$url" in
  "https://wallhaven.cc/api/v1/search"*q=samurai%20city%20%231*page=2*categories=111*purity=100*sorting=date_added*order=desc*) ;;
  *) fail "unexpected Wallhaven URL: $url" ;;
esac

keyed_url=$(WALLHAVEN_API_KEY="key with spaces+symbols" "$script" search --query "forest shrine" --page 1 --print-url)
case "$keyed_url" in
  *apikey=key%20with%20spaces%2Bsymbols*) ;;
  *) fail "search URL should include encoded WALLHAVEN_API_KEY: $keyed_url" ;;
esac

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

cat > "$tmpdir/response.json" <<'JSON'
{
  "data": [
    {
      "id": "abc123",
      "url": "https://wallhaven.cc/w/abc123",
      "path": "https://w.wallhaven.cc/full/ab/wallhaven-abc123.jpg",
      "thumbs": {
        "small": "https://th.wallhaven.cc/small/ab/abc123.jpg"
      },
      "file_type": "image/jpeg",
      "resolution": "1920x1080",
      "colors": ["#cc3333", "#333333"]
    },
    {
      "id": "def456",
      "url": "https://wallhaven.cc/w/def456",
      "path": "https://w.wallhaven.cc/full/de/wallhaven-def456.png",
      "file_type": "image/png",
      "resolution": "2560x1440",
      "colors": ["#3366cc"]
    }
  ],
  "meta": {"current_page": 1, "last_page": 1}
}
JSON

"$script" parse "$tmpdir/response.json" \
  | jq -s -e '
      length == 2
      and .[0].source == "wallhaven"
      and .[0].type == "image"
      and .[0].id == "abc123"
      and .[0].name == "wallhaven-abc123"
      and .[0].path == "https://w.wallhaven.cc/full/ab/wallhaven-abc123.jpg"
      and .[0].thumb == "https://th.wallhaven.cc/small/ab/abc123.jpg"
      and .[0].wallhaven_url == "https://wallhaven.cc/w/abc123"
      and .[0].resolution == "1920x1080"
      and .[0].colors == ["#cc3333", "#333333"]
      and .[0].hue == 99
      and .[0].mtime == 0
      and .[1].thumb == "https://w.wallhaven.cc/full/de/wallhaven-def456.png"
    ' >/dev/null \
  || fail "parse should emit normalized wallhaven rows"

mkdir -p "$tmpdir/mockbin" "$tmpdir/config/current"
wallpaper_dir="$tmpdir/Pictures/Wallpapers"
mkdir -p "$wallpaper_dir"
printf '%s\n' "test theme" > "$tmpdir/config/current/theme.name"
cat > "$tmpdir/mockbin/curl" <<'EOF'
#!/bin/bash
set -euo pipefail

out=""
url=""
retry=""
connect_timeout=""
max_time=""
while (( $# )); do
  case "$1" in
    -o)
      out="$2"
      shift 2
      ;;
    --retry)
      retry="$2"
      shift 2
      ;;
    --connect-timeout)
      connect_timeout="$2"
      shift 2
      ;;
    --max-time)
      max_time="$2"
      shift 2
      ;;
    http*)
      url="$1"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

[[ -n $out ]] || exit 64
if [[ $url == "https://wallhaven.cc/api/v1/search"* ]]; then
  [[ $retry == "2" ]] || exit 65
  [[ $connect_timeout == "10" ]] || exit 66
  [[ $max_time == "30" ]] || exit 67
  cp "$MOCK_WALLHAVEN_RESPONSE" "$out"
elif [[ ${MOCK_WALLHAVEN_FAIL_DOWNLOAD:-0} == "1" ]]; then
  printf '%s\n' "partial wallpaper" > "$out"
  exit 22
else
  printf '%s\n' "mock wallpaper" > "$out"
fi
EOF
chmod +x "$tmpdir/mockbin/curl"

PATH="$tmpdir/mockbin:$PATH" \
MOCK_WALLHAVEN_RESPONSE="$tmpdir/response.json" \
  "$script" search --query "samurai city" --page 1 --json \
  | jq -s -e 'length == 2 and .[0].id == "abc123"' >/dev/null \
  || fail "search --json should fetch and emit normalized JSONL"

downloaded=$(
  PATH="$tmpdir/mockbin:$PATH" \
  MOCK_WALLHAVEN_RESPONSE="$tmpdir/response.json" \
  RYOKU_PATH="$PWD" \
  RYOKU_CONFIG_PATH="$tmpdir/config" \
  RYOKU_STATE_PATH="$tmpdir/state" \
  RYOKU_WALLPAPER_DIR="$wallpaper_dir" \
    "$script" download abc123 "https://w.wallhaven.cc/full/ab/wallhaven-abc123.png"
)

[[ $downloaded == "$wallpaper_dir/wallhaven-abc123.png" ]] \
  || fail "download should print target path, got $downloaded"
[[ -f $downloaded ]] || fail "download should create target file"

if PATH="$tmpdir/mockbin:$PATH" \
  RYOKU_PATH="$PWD" \
  RYOKU_CONFIG_PATH="$tmpdir/config" \
  RYOKU_STATE_PATH="$tmpdir/state" \
  RYOKU_WALLPAPER_DIR="$wallpaper_dir" \
    "$script" download "../bad" "https://w.wallhaven.cc/full/ab/wallhaven-bad.jpg" >/dev/null 2>"$tmpdir/error.log"; then
  fail "invalid Wallhaven ID should fail"
fi
grep -q "invalid Wallhaven ID" "$tmpdir/error.log" \
  || fail "invalid ID should report a validation error"

if "$script" search --query "x" --page 1 --json --print-url >/dev/null 2>"$tmpdir/error.log"; then
  fail "conflicting search modes should fail"
fi
grep -q "conflicting output modes" "$tmpdir/error.log" \
  || fail "conflicting modes should report a validation error"

failed_target="$wallpaper_dir/wallhaven-fail123.jpg"
if PATH="$tmpdir/mockbin:$PATH" \
  MOCK_WALLHAVEN_FAIL_DOWNLOAD="1" \
  RYOKU_PATH="$PWD" \
  RYOKU_CONFIG_PATH="$tmpdir/config" \
  RYOKU_STATE_PATH="$tmpdir/state" \
  RYOKU_WALLPAPER_DIR="$wallpaper_dir" \
    "$script" download fail123 "https://w.wallhaven.cc/full/fa/wallhaven-fail123.jpg" >/dev/null 2>"$tmpdir/error.log"; then
  fail "failed download should fail"
fi
[[ ! -e $failed_target ]] || fail "failed download should not leave final target"
if find "$wallpaper_dir" -maxdepth 1 -name '.wallhaven-fail123.jpg.*.tmp' | grep -q .; then
  fail "failed download should clean temporary target"
fi

if "$script" search --query "missing page" --json >/dev/null 2>"$tmpdir/error.log"; then
  fail "search missing --page should fail"
fi
grep -q "missing --page" "$tmpdir/error.log" \
  || fail "missing --page should report a validation error"

if "$script" search --query "x" --page 1 --bogus >/dev/null 2>"$tmpdir/error.log"; then
  fail "unknown option should fail"
fi
grep -q "unknown option" "$tmpdir/error.log" \
  || fail "unknown option should report a validation error"

pass "ryoku wallhaven search"
