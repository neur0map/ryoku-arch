#!/bin/bash
# Static guard: QML files that use bare ColorUtils must import the
# functions module themselves. Imports from parent components do not
# satisfy child component files loaded by Quickshell.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

missing=()
while IFS= read -r file; do
  rel="${file#$ROOT_DIR/}"
  if rg -q '\bColorUtils\.' "$file" \
    && ! rg -q '^import qs\.modules\.common\.functions(\s|$)' "$file"; then
    missing+=("$rel")
  fi
done < <(find "$ROOT_DIR/shell" -name '*.qml' -type f | sort)

if (( ${#missing[@]} > 0 )); then
  printf 'Missing ColorUtils import:\n' >&2
  printf '  %s\n' "${missing[@]}" >&2
  fail "QML files using ColorUtils must import qs.modules.common.functions"
fi

echo "PASS: tests/qml-colorutils-imports.sh"
