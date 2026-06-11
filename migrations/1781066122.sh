echo "Wire suspend-then-hibernate for laptops that already have hibernation set up."
echo "A plain lid suspend can rot in s2idle overnight on s2idle-only laptops and never"
echo "wake; route lid + suspend key through suspend-then-hibernate with a HibernateDelaySec."

# Only touch machines that already opted into hibernation (resume hook present).
# ryoku-hibernation-setup --write-sth-config re-checks readiness and is a no-op on
# desktops' lid handling and on machines with no usable hibernate image, so it is safe
# everywhere; this guard just avoids needless work on boxes without hibernation.
resume_conf="/etc/mkinitcpio.conf.d/ryoku_resume.conf"
if [[ -f $resume_conf ]] && grep -q "^HOOKS+=(resume)$" "$resume_conf"; then
  "$RYOKU_PATH/bin/ryoku-hibernation-setup" --write-sth-config
fi

echo "Retire hypridle: the Ryoku shell now owns idle (screensaver/DPMS/lock/suspend)"
echo "and the logind lock bridge, so a still-enabled hypridle only double-fires timers."

if command -v systemctl >/dev/null 2>&1; then
  systemctl --user disable --now hypridle.service >/dev/null 2>&1 || true
  systemctl --user mask hypridle.service >/dev/null 2>&1 || true
fi
hypr_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
user_systemd="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
rm -f "$hypr_dir/hypridle.conf" "$hypr_dir/hypridle-rebirth.conf"
rm -f "$user_systemd/graphical-session.target.wants/hypridle.service"
if command -v systemctl >/dev/null 2>&1; then
  systemctl --user daemon-reload >/dev/null 2>&1 || true
fi
