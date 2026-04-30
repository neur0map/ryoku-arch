#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

script="bin/ryoku-restart-ui"
bindings="default/hypr/bindings/utilities.conf"

[[ -f $script ]] || fail "$script missing"
[[ -x $script ]] || fail "$script should be executable"
bash -n "$script" || fail "$script has a syntax error"

grep -q 'bindd = SUPER SHIFT CTRL, R, Hard refresh, exec, ryoku-restart-ui --quiet' "$bindings" \
  || fail "SUPER+CTRL+SHIFT+R should run the hard refresh"

grep -q 'hyprctl dispatch submap reset' "$script" \
  || fail "hard refresh should reset stuck Hyprland submaps"
grep -q 'hyprctl reload' "$script" \
  || fail "hard refresh should reload Hyprland config"
grep -q 'ryoku-restart-shell' "$script" \
  || fail "hard refresh should collapse duplicate Ryoku Quickshell topbars through the shell restart"
grep -q 'restart_always "mako"' "$script" \
  || fail "hard refresh should refresh the notification daemon"
grep -q 'restart_always "swayosd-server"' "$script" \
  || fail "hard refresh should refresh SwayOSD"
grep -q 'restart_if_running "waybar"' "$script" \
  || fail "hard refresh should only restart Waybar when it is already running"
grep -q 'restart_if_running "hypridle"' "$script" \
  || fail "hard refresh should not force-start disabled idle locking"
grep -q 'restart_clipboard_watchers' "$script" \
  || fail "hard refresh should repair duplicate clipboard watchers"
grep -Fq '(^|/)wl-paste --type text --watch cliphist store$' "$script" \
  || fail "hard refresh should remove text clipboard watchers launched from an absolute wl-paste path"
grep -Fq '(^|/)wl-paste --type image --watch cliphist store$' "$script" \
  || fail "hard refresh should remove image clipboard watchers launched from an absolute wl-paste path"
grep -q 'xdg-desktop-portal-hyprland.service' "$script" \
  || fail "hard refresh should try-restart the Hyprland portal"
grep -q 'systemctl --user try-restart' "$script" \
  || fail "hard refresh should use try-restart for user services"

for app in firefox chromium brave code ghostty kitty alacritty spotify signal discord obsidian steam; do
  if grep -E "pkill|killall|systemctl" "$script" | grep -Eq "(^|[[:space:]])$app($|[[:space:]])"; then
    fail "hard refresh should not target user app process: $app"
  fi
done

pass "Ryoku hard refresh contract"
