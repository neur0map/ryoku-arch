echo "Autostart the polkit authentication agent so privileged GUI actions prompt"

# The managed hyprland.conf now autostarts polkit-gnome's authentication agent.
# Without an agent, no password prompt appears for privileged GUI actions (the
# qylock greeter, mounting drives, etc.). Bring the managed config to existing
# installs; user overrides live in hypr/custom.conf and are preserved.
ryoku-refresh-config hypr/hyprland.conf

# Start it in the running session too, so prompts work without a relogin.
polkit_agent="/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
if [[ -x $polkit_agent ]] && ! pgrep -f polkit-gnome-authentication-agent-1 >/dev/null 2>&1; then
  if command -v hyprctl >/dev/null 2>&1; then
    hyprctl dispatch exec "$polkit_agent" >/dev/null 2>&1 || true
  fi
fi
