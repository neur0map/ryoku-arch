echo "Migrate omarchy lockscreen setup to qylock"

MARKER="$HOME/.local/state/ryoku/independence-cutover.qylock.done"

if [[ -f $MARKER ]]; then
  exit 0
fi

if ! ryoku-pkg-aur-accessible; then
  echo "  AUR unavailable; skipping qylock migration. Rerun ryoku-update when network is healthy." >&2
  exit 0
fi

# Install (or re-sync) the qylock theme bundle. --default keeps any
# qylock theme the user already picked; only installs dog-samurai if
# nothing qylock-sourced is active.
ryoku-install-qylock --default

# Turn autologin off so the user actually sees the lockscreen they just
# installed. The omarchy-era install flow enabled autologin by default,
# which defeated the point of a themed greeter. User can re-enable with
# 'ryoku-sddm-autologin enable' if they want the old behavior back.
ryoku-sddm-autologin disable >/dev/null
echo "  autologin disabled (run 'ryoku-sddm-autologin enable' to re-enable)"

mkdir -p "$HOME/.local/state/ryoku"
touch "$MARKER"

echo "  qylock migration complete; reboot to see the new greeter"
