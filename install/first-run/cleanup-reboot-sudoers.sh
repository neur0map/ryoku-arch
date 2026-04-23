for sudoers_file in /etc/sudoers.d/99-ryoku-installer-reboot /etc/sudoers.d/99-omarchy-installer-reboot; do
  if sudo test -f "$sudoers_file"; then
    sudo rm -f "$sudoers_file"
  fi
done
