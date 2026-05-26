#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

mapfile -t qml_files < <(rg --files shell/modules/controlcenter -g '*.qml')

for file in "${qml_files[@]}"; do
  [[ -f $file ]] || continue

  if rg -q '\b(RowLayout|ColumnLayout|GridLayout)\b|Layout\.' "$file"; then
    rg -q '^import QtQuick\.Layouts\b' "$file" || fail "$file uses QtQuick Layouts without importing QtQuick.Layouts"
  fi
done

echo "PASS: settings pages import QtQuick.Layouts when needed"
