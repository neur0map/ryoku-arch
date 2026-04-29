#!/bin/bash
# Spec 1 migration: the Quickshell process is already running at update
# time with the OLD shell.qml that mounts only Frame and ExclusionZones.
# After update, restart it so it picks up the NEW shell.qml that ALSO
# mounts Brain_Shell components. Without this, users wait until next
# session login to see the new shell.

set -e
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"

# Skip if no graphical session.
if [[ -z ${WAYLAND_DISPLAY:-} ]]; then
  exit 0
fi

# Skip if user has explicitly disabled the shell (frame-off toggle).
if ryoku-toggle-enabled frame-off; then
  exit 0
fi

# Mirror the dev tree to the user's installed config (gets the new
# shell.qml + vendor/brain-shell/ tree into ~/.config/quickshell/ryoku/).
ryoku-refresh-quickshell

# Restart the running Quickshell process so it loads the new shell.qml.
# Uses the existing helper which does pkill + setsid-respawn.
ryoku-restart-shell

# Brief grace period, then notify if the new shell came up.
sleep 0.5
if pgrep -x quickshell >/dev/null 2>&1; then
  notify-send -u low \
    "Ryoku Shell updated" \
    "Brain_Shell components are now visible alongside the existing frame and waybar. Click the center of the top to open the Dashboard. To disable everything (frame plus new components), run: ryoku-toggle-frame"
fi
