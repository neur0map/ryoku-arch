echo "Remove omarchy-walker and install tofi/cliphist/bemoji"

MARKER="$HOME/.local/state/ryoku/independence-cutover.launcher.done"

# Idempotent exit if cutover already completed
if [[ -f $MARKER ]]; then
  exit 0
fi

if ! ryoku-pkg-aur-accessible; then
  echo "  AUR unavailable; aborting. Rerun when the network is healthy." >&2
  exit 1
fi

ryoku-snapshot create || true

# Stop running walker so pacman -R is not fighting a live binary
pkill -x walker 2>/dev/null || true

# Install replacements first so the system is never without a launcher.
# tofi and bemoji come from AUR; cliphist is in Arch extra.
ryoku-pkg-aur-add tofi bemoji
ryoku-pkg-add cliphist

# Stop and disable walker autostart unit
systemctl --user disable --now app-walker@autostart.service 2>/dev/null || true
rm -f "$HOME/.config/autostart/walker.desktop"
rm -rf "$HOME/.config/systemd/user/app-walker@autostart.service.d"
systemctl --user daemon-reload 2>/dev/null || true

# Remove the pacman hook that triggered the old walker restart
sudo rm -f /etc/pacman.d/hooks/walker-restart.hook

# Drop omarchy-walker (meta) and orphan cleanup picks up the elephant family
sudo pacman -Rdd --noconfirm omarchy-walker 2>/dev/null || true

# Orphan sweep: walker, elephant, elephant-* become orphans once the
# meta package is gone
orphans=$(pacman -Qdtq 2>/dev/null || true)
if [[ -n $orphans ]]; then
  echo "  Removing orphans:"
  echo "$orphans" | sed 's/^/    /'
  sudo pacman -Rns --noconfirm $orphans
fi

# Clear elephant and walker user config
rm -rf "$HOME/.config/walker" "$HOME/.config/elephant"

# Start cliphist listeners now so the next SUPER+CTRL+V has history
if command -v wl-paste >/dev/null && command -v cliphist >/dev/null; then
  pgrep -f 'wl-paste.*cliphist' >/dev/null || {
    setsid wl-paste --type text --watch cliphist store &>/dev/null &
    setsid wl-paste --type image --watch cliphist store &>/dev/null &
  }
fi

mkdir -p "$HOME/.local/state/ryoku"
touch "$MARKER"

echo "  launcher cutover complete"
