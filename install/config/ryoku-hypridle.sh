#!/bin/bash

# Stages the Ryoku hyprlock + hypridle configs into ~/.config/hypr/ and
# enables the system-shipped hypridle.service. hypridle replaces swayidle
# (Ryoku's Idle.qml is patched by ryoku-shell-branding.sh to skip its
# internal swayidle spawn). On lid-close / suspend-prep, hypridle's
# before_sleep_cmd fires `loginctl lock-session`, which triggers
# lock_cmd (hyprlock) via DBus.
#
# See config/hypr/hypridle.conf header for the full architecture rationale
# and the niri-protocol caveats around inhibit_sleep.

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

# Stage the qt6-fractional-scale-workaround drop-in for ryoku-shell.service.
# This kills a separate Qt 6.11.0 stack overflow on lid-close/output-reconfig
# that would otherwise crash quickshell (see drop-in header for details).
SHELL_DROPIN_SRC="$RYOKU_PATH/config/systemd/user/ryoku-shell.service.d/qt6-fractional-scale-workaround.conf"
SHELL_DROPIN_DEST_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/ryoku-shell.service.d"
if [[ -f $SHELL_DROPIN_SRC ]]; then
  mkdir -p "$SHELL_DROPIN_DEST_DIR"
  install -m 0644 "$SHELL_DROPIN_SRC" "$SHELL_DROPIN_DEST_DIR/qt6-fractional-scale-workaround.conf"
fi

systemctl --user daemon-reload
systemctl --user enable --now hypridle.service >/dev/null 2>&1 || true
