#!/bin/bash
# Propagate three-island topbar additions (cornerStyle 4) into existing
# live installs. Re-syncs the dev tree's runtime-payload directories into
# $SHELL_PATH and triggers $SHELL_PATH/setup install to push to
# $RUNTIME_SHELL_PATH. Idempotent: safe to re-run.
# See: docs/superpowers/specs/2026-05-05-three-island-topbar-design.md

set -euo pipefail
trap 'echo "Migration failed (three-island topbar). Re-run with: bin/ryoku-migrate" >&2' ERR

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"

SHELL_PATH="${RYOKU_SHELL_PATH:-$HOME/.local/share/ryoku-shell}"
DEV_SHELL="$RYOKU_PATH/shell"
PAYLOAD_MANIFEST="$DEV_SHELL/sdata/runtime-payload-dirs.txt"

# If the live shell tree does not exist yet, the next install pass will copy
# everything fresh; nothing to do here.
if [[ ! -d $SHELL_PATH ]]; then
  echo "three-island migration: $SHELL_PATH not present; skipping (fresh install will pick up new files)."
  exit 0
fi

if [[ ! -d $DEV_SHELL ]]; then
  echo "three-island migration: dev shell tree missing at $DEV_SHELL" >&2
  exit 1
fi

# Refresh runtime-payload dirs from dev to vendor (additive; no --delete).
echo "three-island migration: refreshing $SHELL_PATH from $DEV_SHELL ..."
if [[ -f $PAYLOAD_MANIFEST ]]; then
  while IFS= read -r dir; do
    [[ -n $dir ]] || continue
    [[ -d "$DEV_SHELL/$dir" ]] || continue
    mkdir -p "$SHELL_PATH/$dir"
    rsync -a --exclude='AGENTS.md' "$DEV_SHELL/$dir/" "$SHELL_PATH/$dir/"
  done < "$PAYLOAD_MANIFEST"
else
  # Manifest missing: fall back to a hard-coded list matching the spec.
  for dir in modules services scripts assets translations defaults dots sdata; do
    [[ -d "$DEV_SHELL/$dir" ]] || continue
    mkdir -p "$SHELL_PATH/$dir"
    rsync -a --exclude='AGENTS.md' "$DEV_SHELL/$dir/" "$SHELL_PATH/$dir/"
  done
fi

# Re-run the in-tree setup to push vendor -> runtime via its rsync.
if [[ -x $SHELL_PATH/setup ]]; then
  ( cd "$SHELL_PATH" && ./setup install -y --skip-deps --skip-sysupdate )
fi

# Restart so the new files load.
systemctl --user restart ryoku-shell.service >/dev/null 2>&1 || true

echo "three-island migration: complete."
