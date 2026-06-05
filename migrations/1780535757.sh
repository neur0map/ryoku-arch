echo "Replace the hardcoded 1.25 monitor scale with DPI-aware autoscale"

# Ryoku used to ship a hardcoded `scale 1.25` catch-all that applied to every
# monitor, which over-zoomed low-DPI external displays (everything too big). The
# catch-all is now `scale 1` and `ryoku-monitor autoscale` derives a per-panel
# scale from the real pixel density (resolution / physical size), so dense laptop
# panels get bumped while standard external monitors stay at 1x.
#
# Repair an existing monitors.conf: only the shipped default catch-all line is
# rewritten; explicit per-output lines written by Settings > Display are left
# untouched. Then apply the new scaling immediately if a Hyprland session is live,
# so the fix lands without a re-login. Idempotent.

cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
monitors_conf="$cfg/hypr/monitors.conf"

if [[ -f $monitors_conf ]] && grep -qE '^monitor = , highrr, auto, 1\.25$' "$monitors_conf"; then
  sed -i -E 's|^monitor = , highrr, auto, 1\.25$|monitor = , highrr, auto, 1|' "$monitors_conf"
  echo "  monitors.conf catch-all: scale 1.25 -> 1"
fi

# Apply DPI-aware scaling now when run inside a live Hyprland session (best-effort).
if command -v hyprctl >/dev/null 2>&1 && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  "$RYOKU_PATH/bin/ryoku-monitor" autoscale >/dev/null 2>&1 || true
fi
