#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/lib/runtime-env.sh"

INIR_PATH="${RYOKU_INIR_PATH:-$HOME/.local/share/inir}"
SHELL_VENDOR="$RYOKU_PATH/shell"

if [[ ! -d $SHELL_VENDOR ]]; then
  echo "install/config/inir.sh: missing vendored shell tree at $SHELL_VENDOR" >&2
  exit 1
fi

# If the target is a legacy snowarch git checkout, replace it with the vendor.
if [[ -d $INIR_PATH/.git ]]; then
  rm -rf "$INIR_PATH"
fi

# Fresh deploy: copy the vendored tree into place.
if [[ ! -d $INIR_PATH ]]; then
  mkdir -p "$(dirname "$INIR_PATH")"
  cp -a "$SHELL_VENDOR/." "$INIR_PATH/"
fi

(
  cd "$INIR_PATH"
  ./setup install -y --skip-deps --skip-sysupdate
)

"$RYOKU_PATH/install/config/ryoku-shell-branding.sh"

inir_launcher="$HOME/.local/bin/inir"
if [[ -x $inir_launcher ]]; then
  "$inir_launcher" service enable niri >/dev/null 2>&1 || true
elif ryoku-cmd-present inir; then
  inir service enable niri >/dev/null 2>&1 || true
fi

inir_service="$HOME/.config/systemd/user/inir.service"
inir_wants_dir="$HOME/.config/systemd/user/niri.service.wants"
if [[ -f $inir_service ]]; then
  mkdir -p "$inir_wants_dir"
  ln -sf "$inir_service" "$inir_wants_dir/inir.service"
  systemctl --user daemon-reload >/dev/null 2>&1 || true
fi

"$RYOKU_PATH/install/config/ryoku-shell-branding.sh"
systemctl --user daemon-reload >/dev/null 2>&1 || true
