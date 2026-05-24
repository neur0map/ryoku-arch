#!/bin/bash

# Stages the Ryoku hyprlock + hypridle configs into ~/.config/hypr/ and
# enables the system-shipped hypridle.service. hypridle replaces swayidle
# (Ryoku's Idle.qml is patched by ryoku-shell-branding.sh to skip its
# internal swayidle spawn). On lid-close / suspend-prep, hypridle's
# before_sleep_cmd fires `loginctl lock-session`, which triggers lock_cmd
# via DBus. The lock command calls qylock's upstream Quickshell lockscreen
# directly so qylock stays updateable from its own Git checkout.
#
# See config/hypr/hypridle.conf header for the full architecture rationale
# and compositor-specific caveats around inhibit_sleep.

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/lib/runtime-env.sh"

HYPR_CONFIG_SRC="$RYOKU_PATH/config/hypr"
HYPR_CONFIG_DEST="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"

mkdir -p "$HYPR_CONFIG_DEST"

for cfg in hypridle.conf hyprlock.conf; do
  if [[ -f $HYPR_CONFIG_SRC/$cfg ]]; then
    install -m 0644 "$HYPR_CONFIG_SRC/$cfg" "$HYPR_CONFIG_DEST/$cfg"
  fi
done

systemctl --user daemon-reload
systemctl --user enable --now hypridle.service >/dev/null 2>&1 || true
