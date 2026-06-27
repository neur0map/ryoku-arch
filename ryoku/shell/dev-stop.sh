#!/usr/bin/env bash
# stop the dev shell. daemon kills the components it spawned; the shell on
# your own session is left alone.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
"$here/ipc/ryoku-shell" quit 2>/dev/null || true
echo "stopped. if you added the dev keybinds, restore yours with: hyprctl reload"
