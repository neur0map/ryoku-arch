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
  local needle="$2"
  local message="$3"

  grep -Fq "$needle" "$path" || fail "$message"
}

assert_executable bin/ryoku-cmd-gradia
bash -n bin/ryoku-cmd-gradia || fail "Gradia wrapper should have valid bash syntax"
# shellcheck disable=SC2016
assert_contains bin/ryoku-cmd-gradia 'exec flatpak run be.alexandervanhee.gradia "$@"' \
  "Gradia wrapper should preserve the Flatpak fallback when system Gradia is missing"
# shellcheck disable=SC2016
assert_contains bin/ryoku-cmd-image-edit 'ryoku-cmd-gradia "$target"' \
  "image editor helper should launch Gradia through the Ryoku clipboard wrapper"
# shellcheck disable=SC2016
assert_contains bin/ryoku-cmd-screenshot 'gradia_cmd="${RYOKU_SCREENSHOT_GRADIA:-ryoku-cmd-gradia}"' \
  "screenshot helper should launch Gradia through the Ryoku clipboard wrapper"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/fake/gradia"

cat >"$tmp_dir/fake/gradia/__init__.py" <<'PY'
PY

cat >"$tmp_dir/fake/gradia/clipboard.py" <<'PY'
def copy_pixbuf_to_clipboard(pixbuf):
  return None
PY

cat >"$tmp_dir/wl-copy" <<'SH'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >"$RYOKU_TEST_WL_COPY_ARGS"
cat >"$RYOKU_TEST_CLIPBOARD"
SH
chmod +x "$tmp_dir/wl-copy"

PYTHONPATH="$PWD/lib/gradia-clipboard:$tmp_dir/fake" \
PYTHONDONTWRITEBYTECODE=1 \
RYOKU_GRADIA_WL_COPY="$tmp_dir/wl-copy" \
RYOKU_TEST_WL_COPY_ARGS="$tmp_dir/wl-copy-args" \
RYOKU_TEST_CLIPBOARD="$tmp_dir/clipboard" \
python - <<'PY'
import gradia.clipboard

class Pixbuf:
  def savev(self, path, image_format, keys, values):
    with open(path, "wb") as handle:
      handle.write(b"patched png")

if not gradia.clipboard.copy_pixbuf_to_clipboard(Pixbuf()):
  raise SystemExit("patched copy_pixbuf_to_clipboard should report success")
PY

grep -qxF -- '--type image/png' "$tmp_dir/wl-copy-args" || \
  fail "Gradia clipboard patch should send PNG data to wl-copy"
grep -qxF 'patched png' "$tmp_dir/clipboard" || \
  fail "Gradia clipboard patch should write rendered PNG bytes to wl-copy"

echo "PASS: Gradia clipboard wrapper persists copied images through wl-copy"
