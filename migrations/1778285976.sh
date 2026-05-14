#!/bin/bash
# Set Tailscale operator user so the sidebar Connect/Disconnect button can
# control the daemon without sudo. Mirrors install/config/tailscale.sh
# but runs on existing user systems via ryoku-migrate. Idempotent: writes
# the same value if rerun.

set -euo pipefail

echo "Set Tailscale operator user so the sidebar toggle works without sudo"

if ! command -v tailscale >/dev/null 2>&1; then
    echo "  tailscale not installed, skipping"
    exit 0
fi

if ! systemctl is-active tailscaled.service >/dev/null 2>&1; then
    echo "  tailscaled.service not active, skipping"
    exit 0
fi

current_operator=$(tailscale debug prefs 2>/dev/null | grep -oE '"OperatorUser":[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/' || true)
if [[ "$current_operator" == "$USER" ]]; then
    echo "  operator already set to $USER, skipping"
    exit 0
fi

if sudo tailscale set --operator="$USER" >/dev/null 2>&1; then
    echo "  set tailscale --operator=$USER (was: ${current_operator:-unset})"
else
    echo "  could not set tailscale operator; try manually: sudo tailscale set --operator=$USER"
fi
