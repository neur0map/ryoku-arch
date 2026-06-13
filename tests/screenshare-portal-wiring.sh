#!/bin/bash
# Guards Hyprland screen-sharing wiring: the shipped xdph.conf enables token reuse and
# does NOT pin a custom share picker (a stale pin to the removed
# hyprland-preview-share-picker broke source selection in Discord/OBS/Meet), Electron
# apps get the Wayland hint so their PipeWire screencast works, and the repair migration
# strips a dangling pin + adds the env idempotently.

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# ── 1. shipped xdph.conf ──────────────────────────────────────────────────────
xdph="$ROOT/config/hypr/xdph.conf"
[[ -f $xdph ]] || fail "config/hypr/xdph.conf is missing (new installs get no token reuse)"
grep -Eq '^[[:space:]]*allow_token_by_default[[:space:]]*=[[:space:]]*true' "$xdph" \
  || fail "xdph.conf must set allow_token_by_default = true"
# Only an active directive is forbidden; the explanatory comment may mention the key.
grep -Eq '^[[:space:]]*custom_picker_binary[[:space:]]*=' "$xdph" \
  && fail "xdph.conf must NOT pin custom_picker_binary (default picker is installed)"

# ── 2. Electron Wayland hint ──────────────────────────────────────────────────
grep -q 'ELECTRON_OZONE_PLATFORM_HINT' "$ROOT/config/hypr/hyprland.lua" \
  || fail "hyprland.lua must set ELECTRON_OZONE_PLATFORM_HINT for Electron screen sharing"

# ── 3. repair migration: strip dangling pin, add env, idempotent ──────────────
MIG="$ROOT/migrations/1781355954.sh"
[[ -f $MIG ]] || fail "screenshare repair migration is missing"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/.config/hypr" "$WORK/bin"
# Stub side-effecting commands so the test never touches the live portal/config.
for c in systemctl ryoku-refresh-config; do
  printf '#!/bin/bash\nexit 0\n' >"$WORK/bin/$c"
  chmod +x "$WORK/bin/$c"
done
cat >"$WORK/.config/hypr/xdph.conf" <<'EOF'
screencopy {
    custom_picker_binary = hyprland-preview-share-picker
    allow_token_by_default = true
}
EOF
printf 'require("custom")\n' >"$WORK/.config/hypr/hyprland.lua"

run_mig() {
  HOME="$WORK" XDG_CONFIG_HOME="$WORK/.config" RYOKU_PATH="$ROOT" \
    PATH="$WORK/bin:$PATH" bash "$MIG" >/dev/null 2>&1
}

run_mig || fail "migration run failed"
grep -Eq '^[[:space:]]*custom_picker_binary' "$WORK/.config/hypr/xdph.conf" \
  && fail "migration must remove the stale custom_picker_binary pin"
grep -q 'allow_token_by_default = true' "$WORK/.config/hypr/xdph.conf" \
  || fail "migration must keep allow_token_by_default"
grep -q 'ELECTRON_OZONE_PLATFORM_HINT' "$WORK/.config/hypr/hyprland.lua" \
  || fail "migration must add the Electron Wayland hint to the live hyprland config"

run_mig || fail "second migration run failed"
(( $(grep -c 'ELECTRON_OZONE_PLATFORM_HINT' "$WORK/.config/hypr/hyprland.lua") == 1 )) \
  || fail "migration must be idempotent (no duplicate env line)"

echo "PASS: screenshare-portal-wiring"
