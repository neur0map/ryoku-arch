#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

if rg -qi 'ni''ri|in''ir' migrations; then
  echo "FAIL: migrations should not contain retired compositor or shell references" >&2
  exit 1
fi

echo "PASS: rebirth migrations are compositor-free"
