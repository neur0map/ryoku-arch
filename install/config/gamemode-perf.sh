# Install the game mode hardware-performance plumbing: a root template unit the
# shell starts/stops (ryoku-gamemode-perf@full/base) and the polkit rule that
# lets active wheel sessions do so without a password. The unit runs as root, so
# its ExecStart helper must be root-owned and not user-writable -- otherwise the
# passwordless polkit rule would let any active wheel session rewrite the helper
# in its own tree and gain passwordless root. We install a root-owned copy under
# /usr/local/lib/ryoku/ and point the unit there.

sudo install -m 644 -o root -g root \
  "$RYOKU_PATH/default/polkit/49-ryoku-gamemode.rules" \
  /etc/polkit-1/rules.d/49-ryoku-gamemode.rules

sudo install -Dm755 -o root -g root \
  "$RYOKU_PATH/bin/ryoku-gamemode-perf" \
  /usr/local/lib/ryoku/ryoku-gamemode-perf

cat <<EOF | sudo tee /etc/systemd/system/ryoku-gamemode-perf@.service >/dev/null
[Unit]
Description=Ryoku game mode hardware performance knobs (%i)

[Service]
Type=oneshot
RemainAfterExit=yes
NoNewPrivileges=yes
TimeoutStartSec=10
TimeoutStopSec=10
ExecStart=/usr/local/lib/ryoku/ryoku-gamemode-perf enable %i
ExecStop=/usr/local/lib/ryoku/ryoku-gamemode-perf disable %i
EOF

sudo systemctl daemon-reload
