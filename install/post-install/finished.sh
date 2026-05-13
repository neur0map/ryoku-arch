stop_install_log

# tte (python-terminaltexteffects) is AUR-only. If aur-core could not
# reach AUR during install, fall back to plain output so this script
# doesn't blow up at the very end of the run with "tte: command not
# found" right when the user is reading it.
echo_in_style() {
  if command -v tte >/dev/null; then
    echo "$1" | tte --canvas-width 0 --anchor-text c --frame-rate 640 print
  else
    echo "$1"
  fi
}

clear
echo
if command -v tte >/dev/null; then
  tte -i ~/.local/share/ryoku/assets/brand/logo.txt --canvas-width 0 --anchor-text c --frame-rate 920 laseretch
else
  cat ~/.local/share/ryoku/assets/brand/logo.txt 2>/dev/null
fi
echo

# Display installation time if available
if [[ -f $RYOKU_INSTALL_LOG_FILE ]] && grep -q "Total:" "$RYOKU_INSTALL_LOG_FILE" 2>/dev/null; then
  echo
  TOTAL_TIME=$(tail -n 20 "$RYOKU_INSTALL_LOG_FILE" | grep "^Total:" | sed 's/^Total:[[:space:]]*//')
  if [[ -n $TOTAL_TIME ]]; then
    echo_in_style "Installed in $TOTAL_TIME"
  fi
else
  echo_in_style "Finished installing"
fi

# Remove the install-wide NOPASSWD drop-in. Use a single sudo invocation
# so we don't get prompted for a password on the second iteration of a
# loop after NOPASSWD has just been pulled.
sudo rm -f /etc/sudoers.d/99-ryoku-installer /etc/sudoers.d/99-omarchy-installer &>/dev/null

# Exit gracefully if user chooses not to reboot
if gum confirm --padding "0 0 0 $((PADDING_LEFT + 32))" --show-help=false --default --affirmative "Reboot Now" --negative "" ""; then
  # Clear screen to hide any shutdown messages
  clear

  if [[ -n ${RYOKU_CHROOT_INSTALL:-} ]]; then
    touch /var/tmp/ryoku-install-completed
    exit 0
  else
    sudo reboot 2>/dev/null
  fi
fi
