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

[[ -f $script ]] || fail "$script missing"
[[ -x $script ]] || fail "$script should be executable"
bash -n "$script" || fail "$script has a syntax error"

grep -q 'ryoku-restart-shell' "$script" \
  || fail "hard refresh should restart the iNiR shell through ryoku-restart-shell"
grep -q 'restart_clipboard_watchers' "$script" \
  || fail "hard refresh should repair duplicate clipboard watchers"
grep -Fq '(^|/)wl-paste --type text --watch cliphist store$' "$script" \
  || fail "hard refresh should remove text clipboard watchers launched from an absolute wl-paste path"
grep -Fq '(^|/)wl-paste --type image --watch cliphist store$' "$script" \
  || fail "hard refresh should remove image clipboard watchers launched from an absolute wl-paste path"
grep -q 'xdg-desktop-portal-gnome.service' "$script" \
  || fail "hard refresh should try-restart the GNOME portal used by Niri"
grep -q 'xdg-desktop-portal-gtk.service' "$script" \
  || fail "hard refresh should try-restart the GTK portal"
grep -q 'systemctl --user try-restart' "$script" \
  || fail "hard refresh should use try-restart for user services"

if grep -Eq 'hyprctl reload|xdg-desktop-portal-hyprland|restart_always "mako"|swayosd-server|restart_if_running "waybar"|restart_if_running "hypridle"' "$script"; then
  fail "hard refresh should not manage old Hyprland-era UI daemons"
fi

for app in firefox chromium brave code ghostty kitty alacritty spotify signal discord obsidian steam; do
  if grep -E "pkill|killall|systemctl" "$script" | grep -Eq "(^|[[:space:]])$app($|[[:space:]])"; then
    fail "hard refresh should not target user app process: $app"
  fi
done

pass "Ryoku hard refresh contract"
