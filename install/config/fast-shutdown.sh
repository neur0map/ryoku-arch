sudo mkdir -p /etc/systemd/system.conf.d
sudo cp "$RYOKU_PATH/default/systemd/faster-shutdown.conf" /etc/systemd/system.conf.d/10-faster-shutdown.conf
sudo mkdir -p /etc/systemd/system/user@.service.d
sudo cp "$RYOKU_PATH/default/systemd/user@.service.d/faster-shutdown.conf" /etc/systemd/system/user@.service.d/faster-shutdown.conf
sudo systemctl daemon-reload
