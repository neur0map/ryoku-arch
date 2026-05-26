echo "Repair shell screen recorder command wiring"

ryoku-pkg-add slurp gpu-screen-recorder >/dev/null 2>&1 || true

xdg_bin_home="${XDG_BIN_HOME:-$HOME/.local/bin}"
xdg_bin_lib="$(dirname "$xdg_bin_home")/lib"

mkdir -p "$xdg_bin_home" "$xdg_bin_lib"

if [[ -x $RYOKU_PATH/bin/ryoku-cmd-screenrecord ]]; then
  ln -sfn "$RYOKU_PATH/bin/ryoku-cmd-screenrecord" "$xdg_bin_home/ryoku-cmd-screenrecord"
fi

if [[ -f $RYOKU_PATH/lib/runtime-env.sh ]]; then
  ln -sfn "$RYOKU_PATH/lib/runtime-env.sh" "$xdg_bin_lib/runtime-env.sh"
fi

if [[ -x $RYOKU_PATH/shell/setup ]]; then
  RYOKU_DEV_PATH="$RYOKU_PATH" "$RYOKU_PATH/shell/setup" install -y -q --skip-deps --skip-setups --skip-sysupdate --skip-build >/dev/null 2>&1 || true
fi

if ryoku-cmd-present systemctl; then
  systemctl --user restart ryoku-shell.service >/dev/null 2>&1 || true
fi
