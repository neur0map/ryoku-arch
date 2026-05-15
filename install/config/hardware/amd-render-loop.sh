# Set QSG_RENDER_LOOP=basic on AMD GPUs to prevent ghosting, flickering,
# and rendering glitches caused by the threaded render loop with RADV
# drivers (QTBUG-113700). Affects Framework 16 (AMD 7040 APU) and other
# AMD GPU systems.

if ryoku-hw-amd-gpu; then
  dropin="$RYOKU_PATH/config/systemd/user/ryoku-shell.service.d/amd-render-loop.conf"
  target="$HOME/.config/systemd/user/ryoku-shell.service.d/amd-render-loop.conf"

  if [[ -f $dropin ]]; then
    mkdir -p "$(dirname "$target")"
    cp -f "$dropin" "$target"
    systemctl --user daemon-reload
  fi
fi
