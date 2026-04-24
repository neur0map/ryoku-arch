echo "Remove omarchy-keyring"

MARKER="$HOME/.local/state/ryoku/independence-cutover.keyring.done"

if [[ -f $MARKER ]]; then
  exit 0
fi

if ! pacman -Qi omarchy-keyring &>/dev/null; then
  echo "  omarchy-keyring already absent"
  mkdir -p "$HOME/.local/state/ryoku"
  touch "$MARKER"
  # Clear the cross-task started marker once the final cutover migration wraps
  rm -f "$HOME/.local/state/ryoku/independence-cutover.started"
  exit 0
fi

ryoku-snapshot create || true

# Remove the keyring and revoke its trusted key fingerprint. -Rdd skips
# dependency checks; at this point no other package should depend on it,
# but -Rdd shields against lingering stale deps if anything slipped
# through.
sudo pacman -Rdd --noconfirm omarchy-keyring
sudo pacman-key --delete 40DFB630FF42BCFFB047046CF0134EE680CAC571 2>/dev/null || true

# Orphan sweep
orphans=$(pacman -Qdtq 2>/dev/null || true)
if [[ -n $orphans ]]; then
  echo "  removing orphans:"
  echo "$orphans" | sed 's/^/    /'
  sudo pacman -Rns --noconfirm $orphans
fi

# Clean up the legacy user-level omarchy-battery-monitor compat unit
# files. The active timer has been ryoku-battery-monitor since Task 9
# of the Category 1 rename.
for f in omarchy-battery-monitor.timer omarchy-battery-monitor.service; do
  if [[ -f $HOME/.config/systemd/user/$f ]]; then
    systemctl --user disable --now "$f" 2>/dev/null || true
    rm -f "$HOME/.config/systemd/user/$f"
  fi
done
systemctl --user daemon-reload 2>/dev/null || true

mkdir -p "$HOME/.local/state/ryoku"
touch "$MARKER"
rm -f "$HOME/.local/state/ryoku/independence-cutover.started"

echo "  omarchy-keyring removed; Path A cutover complete"
