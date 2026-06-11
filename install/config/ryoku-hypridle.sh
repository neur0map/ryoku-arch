#!/bin/bash

# Idle and lock are owned by the Ryoku shell now:
#   - shell/modules/IdleMonitors.qml drives screensaver / DPMS / lock / suspend
#     from GlobalConfig.general.idle (the single source of truth), and
#   - shell/modules/LockBridge.qml renders qylock on logind Session Lock and
#     before sleep via the C++ LogindManager (Ryoku.Internal).
#
# hypridle is retired: leaving it enabled double-fires the screensaver/lock
# timers and its graphical-session.target gating left it dead on plain
# start-hyprland sessions. This step masks it and removes its stale config, and
# still stages the hyprlock config the lock keybind references.

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/lib/runtime-env.sh"

HYPR_CONFIG_SRC="$RYOKU_PATH/config/hypr"
HYPR_CONFIG_DEST="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
USER_SYSTEMD="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

mkdir -p "$HYPR_CONFIG_DEST"

if [[ -f $HYPR_CONFIG_SRC/hyprlock.conf ]]; then
  install -m 0644 "$HYPR_CONFIG_SRC/hyprlock.conf" "$HYPR_CONFIG_DEST/hyprlock.conf"
fi

# Drop the retired hypridle config + its graphical-session autostart link.
rm -f "$HYPR_CONFIG_DEST/hypridle.conf" "$HYPR_CONFIG_DEST/hypridle-rebirth.conf"
rm -f "$USER_SYSTEMD/graphical-session.target.wants/hypridle.service"

# Stop + mask the service so nothing (dependency or hand-enable) revives it.
if command -v systemctl >/dev/null 2>&1; then
  systemctl --user disable --now hypridle.service >/dev/null 2>&1 || true
  systemctl --user mask hypridle.service >/dev/null 2>&1 || true
  systemctl --user daemon-reload >/dev/null 2>&1 || true
fi
