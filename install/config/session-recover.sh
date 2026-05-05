#!/bin/bash

set -euo pipefail

sudo mkdir -p /usr/lib/systemd/system-sleep

for hook in ryoku-session-recover ryoku-qylock-prelock; do
  sudo install -m 0755 -o root -g root "$RYOKU_PATH/default/systemd/system-sleep/$hook" /usr/lib/systemd/system-sleep/
done
