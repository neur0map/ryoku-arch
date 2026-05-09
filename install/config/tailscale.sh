# Enable tailscaled.service so Tailscale starts at boot. SecPulse polls
# the daemon for status and the Trayscale GUI talks to it on click.
# Users still run `tailscale up` (or click into Trayscale) to log in
# the first time.

if ryoku-cmd-present tailscale && systemctl list-unit-files tailscaled.service >/dev/null 2>&1; then
  sudo systemctl enable --now tailscaled.service
fi

# Set the Tailscale operator user so the user account can run
# `tailscale up`, `tailscale down`, and other control commands without
# sudo. The sidebar Connect/Disconnect button relies on this being set.
# Idempotent: writes the same value if rerun.
if ryoku-cmd-present tailscale && systemctl is-active tailscaled.service >/dev/null 2>&1; then
  sudo tailscale set --operator="$USER" >/dev/null 2>&1 || true
fi
