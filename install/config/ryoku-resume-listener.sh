#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/lib/runtime-env.sh"

UNIT_SRC="$RYOKU_PATH/config/systemd/user/ryoku-resume-listener.service"
UNIT_DEST_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
UNIT_DEST="$UNIT_DEST_DIR/ryoku-resume-listener.service"

if [[ ! -f $UNIT_SRC ]]; then
  echo "ryoku-resume-listener: unit source missing: $UNIT_SRC" >&2
  exit 1
fi

mkdir -p "$UNIT_DEST_DIR"
install -m 0644 "$UNIT_SRC" "$UNIT_DEST"

# In the install chroot there is no user-session bus, so these no-op (|| true);
# install/preflight/ensure-shell-deployment.sh creates the wants-link so the unit
# still enables on first boot. On a live system this enables + starts it.
systemctl --user daemon-reload >/dev/null 2>&1 || true
systemctl --user disable ryoku-resume-listener.service >/dev/null 2>&1 || true
systemctl --user enable --now ryoku-resume-listener.service >/dev/null 2>&1 || true
