# Raise systemd's file descriptor limit for dev tools, browsers, databases,
# containers, and shell services that can exceed the low default.
sudo mkdir -p /etc/systemd/system.conf.d /etc/systemd/user.conf.d

sudo tee /etc/systemd/system.conf.d/99-ryoku-nofile.conf >/dev/null <<'EOF'
[Manager]
DefaultLimitNOFILE=65536:524288
EOF

sudo cp /etc/systemd/system.conf.d/99-ryoku-nofile.conf \
        /etc/systemd/user.conf.d/99-ryoku-nofile.conf
