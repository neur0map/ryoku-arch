#!/bin/bash
# Static and command-behavior checks for the focused app scratchpad.

set -e
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

bindings="default/hypr/bindings/tiling-v2.conf"
toggle="bin/ryoku-hyprland-scratchpad-toggle"
window_toggle="bin/ryoku-hyprland-scratchpad-window-toggle"

[[ -f $bindings ]] || fail "tiling-v2 bindings missing"
[[ -x $toggle ]] || fail "focused app scratchpad toggle command missing"
[[ -x $window_toggle ]] || fail "focused app window toggle command missing"

grep -q 'bindd = SUPER, E, Toggle focused app, exec, ryoku-hyprland-scratchpad-toggle' "$bindings" \
  || fail "Super+E should open/close an existing focused app scratchpad"
grep -q 'bindd = SUPER ALT, E, Toggle app focus, exec, ryoku-hyprland-scratchpad-window-toggle' "$bindings" \
  || fail "Super+Alt+E should add/remove the active app from focus"
! grep -q 'bindd = SUPER, H, Toggle scratchpad' "$bindings" \
  || fail "Super+H should no longer toggle the scratchpad"
! grep -q 'bindd = SUPER SHIFT, H, Hide scratchpad' "$bindings" \
  || fail "Super+Shift+H should no longer hide the scratchpad"
! grep -q 'bindd = SUPER ALT, H, Move window to scratchpad' "$bindings" \
  || fail "Super+Alt+H should no longer move windows to scratchpad"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/bin"
cat >"$tmpdir/bin/hyprctl" <<'STUB'
#!/bin/bash
case "$*" in
  "clients -j")
    cat "$HYPRCTL_CLIENTS_JSON"
    ;;
  "activewindow -j")
    cat "$HYPRCTL_ACTIVEWINDOW_JSON"
    ;;
  "monitors -j")
    cat "$HYPRCTL_MONITORS_JSON"
    ;;
  dispatch*)
    printf '%s\n' "$*" >>"$HYPRCTL_CALLS"
    ;;
  *)
    printf 'unexpected hyprctl call: %s\n' "$*" >&2
    exit 1
    ;;
esac
STUB
chmod +x "$tmpdir/bin/hyprctl"

export HYPRCTL_CLIENTS_JSON="$tmpdir/clients.json"
export HYPRCTL_ACTIVEWINDOW_JSON="$tmpdir/activewindow.json"
export HYPRCTL_MONITORS_JSON="$tmpdir/monitors.json"
export HYPRCTL_CALLS="$tmpdir/calls"
export RYOKU_STATE_PATH="$tmpdir/state"
export RYOKU_PATH="$PWD"
export PATH="$tmpdir/bin:$PATH"

write_monitors() {
  cat >"$HYPRCTL_MONITORS_JSON" <<'JSON'
[
  {
    "focused": true,
    "activeWorkspace": { "id": 2, "name": "2" },
    "specialWorkspace": { "id": 0, "name": "" }
  }
]
JSON
}

write_visible_monitors() {
  cat >"$HYPRCTL_MONITORS_JSON" <<'JSON'
[
  {
    "focused": true,
    "activeWorkspace": { "id": 2, "name": "2" },
    "specialWorkspace": { "id": -98, "name": "special:scratchpad" }
  }
]
JSON
}

write_normal_active_window() {
  cat >"$HYPRCTL_ACTIVEWINDOW_JSON" <<'JSON'
{
  "address": "0xabc",
  "workspace": { "id": 2, "name": "2" }
}
JSON
}

write_scratchpad_active_window() {
  cat >"$HYPRCTL_ACTIVEWINDOW_JSON" <<'JSON'
{
  "address": "0xabc",
  "workspace": { "id": -98, "name": "special:scratchpad" }
}
JSON
}

write_monitors
printf '[]\n' >"$HYPRCTL_CLIENTS_JSON"
: >"$HYPRCTL_CALLS"
"$toggle"
[[ ! -s $HYPRCTL_CALLS ]] \
  || fail "Super+E command should do nothing when no app is in the focused scratchpad"

cat >"$HYPRCTL_CLIENTS_JSON" <<'JSON'
[
  { "workspace": { "name": "1" } },
  { "workspace": { "name": "special:scratchpad" } }
]
JSON
: >"$HYPRCTL_CALLS"
"$toggle"
grep -qx 'dispatch togglespecialworkspace scratchpad' "$HYPRCTL_CALLS" \
  || fail "Super+E command should toggle scratchpad when an app is parked"

write_normal_active_window
: >"$HYPRCTL_CALLS"
"$window_toggle"
grep -qx 'dispatch movetoworkspacesilent special:scratchpad,address:0xabc' "$HYPRCTL_CALLS" \
  || fail "Super+Alt+E should park the active app silently"
grep -qx $'0xabc\t2' "$RYOKU_STATE_PATH/hypr/scratchpad-workspaces.tsv" \
  || fail "Super+Alt+E should remember the app's original workspace"

write_scratchpad_active_window
write_visible_monitors
: >"$HYPRCTL_CALLS"
"$window_toggle"
grep -qx 'dispatch movetoworkspacesilent 2,address:0xabc' "$HYPRCTL_CALLS" \
  || fail "Super+Alt+E should restore a focused app to its original workspace"
grep -qx 'dispatch togglespecialworkspace scratchpad' "$HYPRCTL_CALLS" \
  || fail "Super+Alt+E should close the scratchpad after restoring the app"
grep -qx 'dispatch workspace 2' "$HYPRCTL_CALLS" \
  || fail "Super+Alt+E should switch back to the restored app workspace"
! grep -q '0xabc' "$RYOKU_STATE_PATH/hypr/scratchpad-workspaces.tsv" \
  || fail "Super+Alt+E should clear restored app state"

cat >"$HYPRCTL_ACTIVEWINDOW_JSON" <<'JSON'
{
  "address": "0xdef",
  "workspace": { "id": -98, "name": "special:scratchpad" }
}
JSON
: >"$HYPRCTL_CALLS"
"$window_toggle"
grep -qx 'dispatch movetoworkspacesilent 2,address:0xdef' "$HYPRCTL_CALLS" \
  || fail "Super+Alt+E should restore old scratchpad apps to the current workspace"

pass "focused app scratchpad bindings and commands"
