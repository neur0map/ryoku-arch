echo "Tune Ryoku shell resume recovery: faster restart and no graphical-session kill tie"

tmp_service="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/ryoku-shell.service"

if [[ -f $tmp_service ]]; then
  sed -i \
    -e '/^PartOf=graphical-session.target$/d' \
    -e '/^Requisite=graphical-session.target$/d' \
    -e '/^RestartSec=/d' \
    "$tmp_service"
  printf '%s\n' "RestartSec=1" >> "$tmp_service"
fi

if [[ -f $RYOKU_PATH/default/systemd/system-sleep/ryoku-session-recover ]]; then
  sed -i 's/^sleep 3$/sleep 1/' "$RYOKU_PATH/default/systemd/system-sleep/ryoku-session-recover"
fi

systemctl --user daemon-reload >/dev/null 2>&1 || true
