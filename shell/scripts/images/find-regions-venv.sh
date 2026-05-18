#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -n "${RYOKU_SHELL_VENV:-}" ]]; then
    _ryoku_venv="$(eval echo "$RYOKU_SHELL_VENV")"
else
    _ryoku_venv="$HOME/.local/state/quickshell/.venv"
fi
source "$_ryoku_venv/bin/activate" 2>/dev/null || true
"$_ryoku_venv/bin/python3" "$SCRIPT_DIR/find_regions.py" "$@"
deactivate 2>/dev/null || true
