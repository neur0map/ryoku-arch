#!/bin/bash

# Stages the Ryoku hyprlock + hypridle configs into ~/.config/hypr/ and
# enables the system-shipped hypridle.service. hypridle replaces swayidle
# (iNiR's Idle.qml is patched by ryoku-shell-branding.sh to skip its
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

# Stage the qt6-fractional-scale-workaround drop-in for inir.service.
# This kills a separate Qt 6.11.0 stack overflow on lid-close/output-reconfig
# that would otherwise crash quickshell (see drop-in header for details).
INIR_DROPIN_SRC="$RYOKU_PATH/config/systemd/user/inir.service.d/qt6-fractional-scale-workaround.conf"
INIR_DROPIN_DEST_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/inir.service.d"
if [[ -f $INIR_DROPIN_SRC ]]; then
  mkdir -p "$INIR_DROPIN_DEST_DIR"
  install -m 0644 "$INIR_DROPIN_SRC" "$INIR_DROPIN_DEST_DIR/qt6-fractional-scale-workaround.conf"
fi

systemctl --user daemon-reload
systemctl --user enable --now hypridle.service >/dev/null 2>&1 || true
