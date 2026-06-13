#!/bin/bash
# Guards Ryoku-shipped Chromium extensions: every file a manifest references (icons,
# service worker, action icon, content scripts) must exist in the extension dir, and
# the dir must contain no dangling symlinks. A missing reference makes Chromium print
# "Could not load ..." on launch; the bundled copy-url extension once shipped an
# icon.png symlink pointing at a nonexistent root icon, which did exactly that.

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail() {
  echo "FAIL: $*" >&2
  exit 1
}

EXT_ROOT="$ROOT/default/chromium/extensions"
if [[ ! -d $EXT_ROOT ]]; then
  echo "PASS: chromium-extensions-valid (no extensions)"
  exit 0
fi

shopt -s nullglob
checked=0
for ext in "$EXT_ROOT"/*/; do
  name="$(basename "$ext")"
  mf="${ext}manifest.json"
  [[ -f $mf ]] || fail "$name: missing manifest.json"
  jq . "$mf" >/dev/null 2>&1 || fail "$name: manifest.json is not valid JSON"
  checked=1

  # Every relative resource the manifest names must exist (skip URLs / data: URIs).
  while IFS= read -r ref; do
    [[ -n $ref ]] || continue
    [[ $ref == http*://* || $ref == data:* ]] && continue
    [[ -e ${ext}${ref} ]] || fail "$name: manifest references missing file '$ref'"
  done < <(jq -r '
    [ (.icons // {} | .[]),
      (.action.default_icon // {} | (if type == "object" then .[] else . end)),
      (.background.service_worker // empty),
      (.content_scripts // [] | .[] | (.js // [])[], (.css // [])[]) ]
    | .[]' "$mf")

  # No dangling symlinks anywhere under the extension dir.
  while IFS= read -r link; do
    [[ -e $link ]] || fail "$name: dangling symlink '$link'"
  done < <(find "$ext" -type l)
done

(( checked )) || echo "PASS: chromium-extensions-valid (no extensions)"
(( checked )) && echo "PASS: chromium-extensions-valid"
