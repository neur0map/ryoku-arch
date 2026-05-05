#!/bin/bash
# Wipe Ryoku-touched iNiR state and re-bootstrap a pristine upstream
# install from github.com/snowarch/iNiR.git. See spec at
# docs/superpowers/specs/2026-05-04-pristine-inir-restore-design.md.

set -euo pipefail
trap 'echo "Migration failed. Re-run with: bin/ryoku-migrate" >&2' ERR

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"

INIR_PATH="$HOME/.local/share/inir"
USER_CONFIG="$HOME/.config/inir/config.json"
RYOKU_ICON="$HOME/.local/share/icons/hicolor/scalable/apps/ryoku.svg"
WANTS_DIR="$HOME/.config/systemd/user/niri.service.wants"
SERVICE_UNIT="$HOME/.config/systemd/user/inir.service"

# Phase 1: Banner
printf '\n'
printf '\033[1;33mWiping iNiR completely and reinstalling fresh upstream.\033[0m\n'
printf 'Desktop chrome (bar, sidebars, lock UI) will be unavailable for ~1-3 min.\n'
printf 'Existing windows persist (niri keeps running). Do NOT lock the screen.\n'
printf '\n'

# Phase 2: Pre-flight. If iNiR is already absent, exit cleanly.
if [[ ! -x $INIR_PATH/setup ]]; then
  echo "iNiR setup script missing at $INIR_PATH/setup; nothing to wipe."
  exit 0
fi

# Phase 3: Backup user config to a path outside the wipe scope.
ts=$(date +%s)
backup_dir="$RYOKU_STATE_PATH/inir-restore-backup"
mkdir -p "$backup_dir"
if [[ -f $USER_CONFIG ]]; then
  cp "$USER_CONFIG" "$backup_dir/config.json.$ts"
  echo "Backed up user config to $backup_dir/config.json.$ts"
fi

# Phase 4: Stop iNiR services so the unit files can be safely removed.
systemctl --user stop inir.service inir-super-overview.service 2>/dev/null || true

# Phase 5: Run iNiR's own uninstall to remove every iNiR-tracked file.
"$INIR_PATH/setup" uninstall -y

# Phase 6: Wipe the source tree itself (uninstall does not remove its own repo).
rm -rf "$INIR_PATH"

# Phase 7: Wipe Ryoku-only artifacts that iNiR's manifest does not track.
rm -f "$RYOKU_ICON"

# Phase 8: Clone fresh iNiR. Source is the Ryoku-maintained iNiR fork
# once it exists; defaults to the snowarch reference repo until then.
# Override with RYOKU_INIR_REPO=... to point at any other remote.
INIR_REPO="${RYOKU_INIR_REPO:-https://github.com/snowarch/iNiR.git}"
git clone "$INIR_REPO" "$INIR_PATH"

# Phase 9: Run iNiR's installer with non-interactive flags.
"$INIR_PATH/setup" install -y --skip-deps --skip-sysupdate

# Phase 10: Re-create the niri.service.wants symlink so iNiR auto-starts.
mkdir -p "$WANTS_DIR"
ln -sf "$SERVICE_UNIT" "$WANTS_DIR/inir.service"

# Phase 11: Reload user units and start iNiR.
systemctl --user daemon-reload >/dev/null 2>&1 || true
systemctl --user start inir.service

echo
echo "Pristine iNiR restore complete."
if [[ -f $backup_dir/config.json.$ts ]]; then
  echo "Backup of prior config: $backup_dir/config.json.$ts"
fi
