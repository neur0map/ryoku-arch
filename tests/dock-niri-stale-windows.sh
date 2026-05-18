#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local path="$1"
  local needle="$2"

  grep -qF "$needle" "$ROOT_DIR/$path" || fail "$path should contain: $needle"
}

assert_contains "shell/modules/dock/DockApps.qml" "function _toplevelLiveKey(toplevel)"
assert_contains "shell/modules/dock/DockApps.qml" "const tmToplevels = ToplevelManager.toplevels.values;"
assert_contains "shell/modules/dock/DockApps.qml" "const liveToplevelCounts = new Map();"
assert_contains "shell/modules/dock/DockApps.qml" "if (count <= 0) continue;"
assert_contains "shell/modules/dock/DockApps.qml" "liveToplevelCounts.set(key, count - 1);"

assert_contains "shell/services/NiriService.qml" "function toplevelSourceKey(toplevel)"
assert_contains "shell/services/NiriService.qml" "\"_sourceKey\": toplevelSourceKey(toplevel)"
assert_contains "shell/services/NiriService.qml" "if (!bestMatch || bestScore <= 0)"

echo "PASS: dock filters stale Niri toplevels"
