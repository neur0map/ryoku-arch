stop_install_log

echo_in_style() {
  echo "$1" | tte --canvas-width 0 --anchor-text c --frame-rate 640 print
}

clear
echo
tte -i ~/.local/share/ryoku/logo.txt --canvas-width 0 --anchor-text c --frame-rate 920 laseretch
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

for sudoers_file in /etc/sudoers.d/99-ryoku-installer /etc/sudoers.d/99-omarchy-installer; do
  if sudo test -f "$sudoers_file"; then
    sudo rm -f "$sudoers_file" &>/dev/null
  fi
done

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
