#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -n "${RYOKU_SHELL_VENV:-}" ]]; then
    _ryoku_venv="$(eval echo "$RYOKU_SHELL_VENV")"
else
    _ryoku_venv="$HOME/.local/state/quickshell/.venv"
fi
source "$_ryoku_venv/bin/activate" 2>/dev/null || true
GIO_USE_VFS=local "$_ryoku_venv/bin/python3" "$SCRIPT_DIR/thumbgen.py" "$@"
THUMBGEN_EXIT_CODE=$?
deactivate 2>/dev/null || true

exit $THUMBGEN_EXIT_CODE
