#!/bin/bash
# Guards the Wayland screen-share portal fix. xdg-desktop-portal >= 1.20 ships
# Requisite=graphical-session.target, and a bare (non-uwsm) Hyprland session never
# brings that target up -- so the portal frontend (org.freedesktop.portal.Desktop)
# never activates and EVERY Wayland screen-share / file-picker silently fails. The
# fix ships a session-wrapper target that pulls graphical-session.target up, starts
# it from Hyprland on launch, and a migration deploys it + activates it for the
# running session.

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# ── 1. wrapper target unit ────────────────────────────────────────────────────
unit="$ROOT/config/systemd/user/hyprland-session.target"
[[ -f $unit ]] || fail "config/systemd/user/hyprland-session.target is missing"
# BindsTo (not a manual start): graphical-session.target has RefuseManualStart=yes,
# so it can only be pulled in as a dependency.
grep -Eq '^BindsTo=graphical-session.target' "$unit" \
  || fail "wrapper must BindsTo=graphical-session.target"
grep -Eq '^Before=graphical-session.target' "$unit" \
  || fail "wrapper must be ordered Before=graphical-session.target"

# ── 2. Hyprland starts the target + imports the session env on launch ──────────
lua="$ROOT/config/hypr/hyprland.lua"
grep -q 'systemctl --user start hyprland-session.target' "$lua" \
  || fail "hyprland.lua must start hyprland-session.target on launch"
grep -q 'import-environment' "$lua" \
  || fail "hyprland.lua must import the session env so portal services inherit WAYLAND_DISPLAY"

# ── 3. repair migration: deploy unit, bring it up, inject hyprland.lua, idempotent ─
MIG="$ROOT/migrations/1781360775.sh"
[[ -f $MIG ]] || fail "portal repair migration is missing"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/.config/hypr"
: > "$WORK/calls.log"
printf 'require("custom")\n' > "$WORK/.config/hypr/hyprland.lua"
# Record portal-touching commands instead of running them against the live session.
cat >"$WORK/bin/systemctl" <<'EOF'
#!/bin/bash
printf 'systemctl %s\n' "$*" >> "$CALLS_LOG"
exit 0
EOF
cat >"$WORK/bin/ryoku-refresh-config" <<'EOF'
#!/bin/bash
printf 'ryoku-refresh-config %s\n' "$*" >> "$CALLS_LOG"
exit 0
EOF
printf '#!/bin/bash\nexit 0\n' >"$WORK/bin/ryoku-cmd-present"
printf '#!/bin/bash\nexit 0\n' >"$WORK/bin/dbus-update-activation-environment"
printf '#!/bin/bash\nexit 0\n' >"$WORK/bin/hyprctl"
chmod +x "$WORK"/bin/*

run_mig() {
  HOME="$WORK" XDG_CONFIG_HOME="$WORK/.config" CALLS_LOG="$WORK/calls.log" RYOKU_PATH="$ROOT" \
    PATH="$WORK/bin:$PATH" bash "$MIG" >/dev/null 2>&1
}

run_mig || fail "migration run failed"
grep -q 'ryoku-refresh-config systemd/user/hyprland-session.target' "$WORK/calls.log" \
  || fail "migration must deploy the wrapper target via ryoku-refresh-config"
grep -q 'systemctl --user start hyprland-session.target' "$WORK/calls.log" \
  || fail "migration must start hyprland-session.target for the running session"
grep -q 'ryoku: portal session bringup' "$WORK/.config/hypr/hyprland.lua" \
  || fail "migration must inject the portal session bringup into the live hyprland.lua"
grep -q 'ryoku: screen-share indicator' "$WORK/.config/hypr/hyprland.lua" \
  || fail "migration must inject the screen-share indicator rule into hyprland.lua"

run_mig || fail "second migration run failed (must be idempotent)"
(( $(grep -c 'ryoku: portal session bringup' "$WORK/.config/hypr/hyprland.lua") == 1 )) \
  || fail "migration must be idempotent (no duplicate portal bringup)"

echo "PASS: screenshare-portal-session"
