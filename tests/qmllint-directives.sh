#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

if rg -n 'qmllint disable signal-handler-parameters' "$ROOT_DIR/shell" -g '*.qml'; then
  echo "FAIL: Ubuntu qmllint does not recognize signal-handler-parameters directives" >&2
  exit 1
fi

echo "PASS: qmllint directives are compatible with CI"
