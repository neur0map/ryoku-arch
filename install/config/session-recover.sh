#!/bin/bash

set -euo pipefail

sudo mkdir -p /usr/lib/systemd/system-sleep
sudo install -m 0755 -o root -g root "$RYOKU_PATH/default/systemd/system-sleep/ryoku-session-recover" /usr/lib/systemd/system-sleep/
