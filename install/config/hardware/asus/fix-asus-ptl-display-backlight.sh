# Display backlight fix for confirmed ASUS Panther Lake / Xe3 laptops.
#
# The panel reports an empty EDID on eDP-1, so xe chooses VBT/PWM backlight
# while the panel expects DPCD AUX backlight. Sysfs writes appear to work but
# visible brightness does not change without xe.enable_dpcd_backlight=1.

if ryoku-hw-asus-expertbook-b9406 || ryoku-hw-asus-zenbook-ux5406aa; then
  sudo mkdir -p /etc/limine-entry-tool.d
  cat <<EOF | sudo tee /etc/limine-entry-tool.d/ryoku-asus-ptl-display-backlight.conf >/dev/null
# ASUS Panther Lake display backlight fix
KERNEL_CMDLINE[default]+=" xe.enable_dpcd_backlight=1"
EOF
fi
