MARKER="$HOME/.local/state/ryoku/independence-cutover.qylock-nudge.done"

# Idempotent: print the nudge once per system. The migration runs during
# ryoku-update on existing systems; qylock is optional and interactive,
# so this migration does not try to install it - it just points the user
# at the installer if they have not run it yet.

if [[ -f $MARKER ]]; then
  exit 0
fi

has_qylock_theme() {
  find /usr/share/sddm/themes -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while read -r dir; do
    if [[ -d $HOME/.local/share/qylock/themes/$(basename "$dir") ]]; then
      echo yes
      return 0
    fi
  done
}

if [[ -d $HOME/.local/share/qylock ]] && [[ -n $(has_qylock_theme) ]]; then
  # Already set up; silent.
  :
else
  echo ""
  echo "  Ryoku's SDDM theme bundle is now qylock (Darkkal44/qylock)."
  echo "  To install or pick a theme, run:"
  echo ""
  echo "      ryoku-install-qylock"
  echo ""
  echo "  Autologin skips the greeter entirely; toggle with:"
  echo ""
  echo "      ryoku-sddm-autologin disable   # show greeter at boot"
  echo "      ryoku-sddm-autologin enable    # auto-log in again"
  echo ""
fi

mkdir -p "$HOME/.local/state/ryoku"
touch "$MARKER"
