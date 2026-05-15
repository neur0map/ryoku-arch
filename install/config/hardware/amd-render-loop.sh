#!/bin/bash

# Set QSG_RENDER_LOOP=basic on AMD GPUs to prevent ghosting, flickering,
# and rendering glitches caused by the threaded render loop with RADV
# drivers (QTBUG-113700). Affects Framework 16 (AMD 7040 APU) and other
# AMD GPU systems.

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"

if ! ryoku-hw-amd-gpu; then
  log_info "No AMD GPU detected; skipping basic render loop drop-in"
  exit 0
fi

DROPIN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/ryoku-shell.service.d"
mkdir -p "$DROPIN_DIR"

install -m 0644 \
  "$RYOKU_PATH/install/config/hardware/amd-render-loop.conf" \
  "$DROPIN_DIR/amd-render-loop.conf"

systemctl --user daemon-reload

log_ok "AMD GPU basic render loop drop-in installed"
