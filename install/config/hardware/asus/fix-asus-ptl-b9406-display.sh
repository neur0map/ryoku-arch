# Display wake fix for ASUS ExpertBook B9406 on Panther Lake / Xe3.
#
# Panel Replay can latch the last-presented frame in self-refresh and fail to
# wake for later commits. Disable Panel Replay only for this confirmed model.

if ryoku-hw-asus-expertbook-b9406; then
  sudo mkdir -p /etc/limine-entry-tool.d
  cat <<EOF | sudo tee /etc/limine-entry-tool.d/ryoku-asus-expertbook-b9406-display.conf >/dev/null
# ASUS ExpertBook B9406 display workaround
KERNEL_CMDLINE[default]+=" xe.enable_panel_replay=0"
EOF
fi
