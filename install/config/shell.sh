#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/lib/runtime-env.sh"

SHELL_PATH="${RYOKU_SHELL_PATH:-$HOME/.local/share/ryoku-shell}"
SHELL_VENDOR="$RYOKU_PATH/shell"

if [[ ! -d $SHELL_VENDOR ]]; then
  echo "install/config/shell.sh: missing vendored shell tree at $SHELL_VENDOR" >&2
  exit 1
fi

# If the target is a legacy snowarch git checkout, replace it with the vendor.
if [[ -d $SHELL_PATH/.git ]]; then
  rm -rf "$SHELL_PATH"
fi

# Fresh deploy: copy the vendored tree into place.
if [[ ! -d $SHELL_PATH ]]; then
  mkdir -p "$(dirname "$SHELL_PATH")"
  cp -a "$SHELL_VENDOR/." "$SHELL_PATH/"
fi

(
  cd "$SHELL_PATH"
  ./setup install -y --skip-deps --skip-sysupdate
)

"$RYOKU_PATH/install/config/ryoku-shell-branding.sh"

ryoku_shell_launcher="$HOME/.local/bin/ryoku-shell"
if [[ -x $ryoku_shell_launcher ]]; then
  "$ryoku_shell_launcher" service enable niri >/dev/null 2>&1 || true
elif ryoku-cmd-present ryoku-shell; then
  ryoku-shell service enable niri >/dev/null 2>&1 || true
fi

ryoku_shell_service="$HOME/.config/systemd/user/ryoku-shell.service"
ryoku_shell_wants_dir="$HOME/.config/systemd/user/niri.service.wants"
if [[ -f $ryoku_shell_service ]]; then
  mkdir -p "$ryoku_shell_wants_dir"
  ln -sf "$ryoku_shell_service" "$ryoku_shell_wants_dir/ryoku-shell.service"
  systemctl --user daemon-reload >/dev/null 2>&1 || true
fi

"$RYOKU_PATH/install/config/ryoku-shell-branding.sh"
systemctl --user daemon-reload >/dev/null 2>&1 || true
