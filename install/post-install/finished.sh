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

# Exit gracefully if user chooses not to reboot. This prompt defaults to
# affirmative (Reboot Now), so the fallback must default to yes on empty input.
# ryoku-tui is built earlier in the install and is normally present here, but
# guard anyway so the final step never stalls if it is somehow missing.
reboot_confirm() {
  if command -v ryoku-tui &>/dev/null; then
    ryoku-tui confirm --padding "0 0 0 $((PADDING_LEFT + 32))" --show-help=false --default --affirmative "Reboot Now" --negative "" ""
  else
    local answer=""
    if { exec 9</dev/tty; } 2>/dev/null; then
      read -r -p "Reboot Now? [Y/n] " answer <&9 || answer=""
      exec 9<&-
    else
      read -r -p "Reboot Now? [Y/n] " answer || answer=""
    fi
    [[ $answer != [nN]* ]]
  fi
}

if reboot_confirm; then
  # Clear screen to hide any shutdown messages
  clear

  if [[ -n ${RYOKU_CHROOT_INSTALL:-} ]]; then
    # Signal the live ISO wrapper to reboot without writing into the target.
    # Disable the installer traps first; otherwise the intentional non-zero
    # status is treated as a failed install inside the chroot.
    stop_log_output 2>/dev/null || true
    show_cursor 2>/dev/null || true
    trap - ERR INT TERM EXIT
    exit 42
  else
    sudo reboot 2>/dev/null
  fi
fi
