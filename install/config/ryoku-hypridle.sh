#!/bin/bash

# Stages the Ryoku hyprlock + hypridle configs into ~/.config/hypr/ and
# lets the system-shipped hypridle.service own the idle daemon lifecycle.
# hypridle replaces swayidle
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
stale_rebirth_hypridle_pattern='(^|/)hypridle -c .*/hypridle-rebirth[.]conf($| )'

mkdir -p "$HYPR_CONFIG_DEST"

for cfg in hypridle.conf hyprlock.conf; do
  if [[ -f $HYPR_CONFIG_SRC/$cfg ]]; then
    install -m 0644 "$HYPR_CONFIG_SRC/$cfg" "$HYPR_CONFIG_DEST/$cfg"
  fi
done
rm -f "$HYPR_CONFIG_DEST/hypridle-rebirth.conf"

systemctl --user daemon-reload >/dev/null 2>&1 || true
systemctl --user enable --now hypridle.service >/dev/null 2>&1 || true

if systemctl --user is-active --quiet hypridle.service >/dev/null 2>&1 \
  && command -v pgrep >/dev/null 2>&1 \
  && command -v pkill >/dev/null 2>&1 \
  && pgrep -f "$stale_rebirth_hypridle_pattern" >/dev/null 2>&1; then
  pkill -f "$stale_rebirth_hypridle_pattern" >/dev/null 2>&1 || true
fi
