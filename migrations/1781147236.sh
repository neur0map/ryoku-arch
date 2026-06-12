echo "Fix graphical login: sync the SDDM greeter keyboard layout to the console keymap."
echo "The installer only configured the console keymap (used by the disk-unlock prompt and"
echo "TTYs), so the greeter fell back to 'us' and rejected non-US passwords that still work"
echo "on a TTY. ryoku-keymap-sync is a no-op on us-layout and on deliberately-customized"
echo "systems, so this only repairs the affected mismatch."

if [[ -x "$RYOKU_PATH/bin/ryoku-keymap-sync" ]]; then
  "$RYOKU_PATH/bin/ryoku-keymap-sync" || true
fi
