# Install the game mode hardware-performance plumbing: a root template unit the
# shell starts/stops (ryoku-gamemode-perf@full/base) and the polkit rule that
# lets active wheel sessions do so without a password. The helper script lives
# in the installed Ryoku tree; the unit references it by absolute path (system
# units run as root with no $HOME), matching the udev-rule precedent.

sudo install -m 644 -o root -g root \
  "$RYOKU_PATH/default/polkit/49-ryoku-gamemode.rules" \
  /etc/polkit-1/rules.d/49-ryoku-gamemode.rules

cat <<EOF | sudo tee /etc/systemd/system/ryoku-gamemode-perf@.service >/dev/null
[Unit]
Description=Ryoku game mode hardware performance knobs (%i)

[Service]
Type=oneshot
RemainAfterExit=yes
TimeoutStartSec=10
TimeoutStopSec=10
ExecStart=$HOME/.local/share/ryoku/bin/ryoku-gamemode-perf enable %i
ExecStop=$HOME/.local/share/ryoku/bin/ryoku-gamemode-perf disable %i
EOF

sudo systemctl daemon-reload
