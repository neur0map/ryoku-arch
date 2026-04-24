echo "Activate Ryoku Plymouth theme"

MARKER="$HOME/.local/state/ryoku/independence-cutover.plymouth.done"

if [[ -f $MARKER ]]; then
  exit 0
fi

# Skip silently on systems without Plymouth installed.
if ! command -v plymouth-set-default-theme >/dev/null 2>&1; then
  mkdir -p "$HOME/.local/state/ryoku"
  touch "$MARKER"
  exit 0
fi

# If the active theme is already 'ryoku', only make sure the files are
# up to date (ryoku-refresh-plymouth handles that). Otherwise install
# the Ryoku theme and set it as default, which also rebuilds initramfs.
current=$(sudo plymouth-set-default-theme 2>/dev/null || true)

if [[ $current == ryoku ]]; then
  echo "  Plymouth already on ryoku; refreshing assets"
else
  echo "  switching Plymouth theme: ${current:-(none)} -> ryoku"
fi

ryoku-refresh-plymouth

# Drop the legacy omarchy theme dir now that ryoku is active. Keep this
# step gated on the switch having landed successfully.
if sudo plymouth-set-default-theme 2>/dev/null | grep -q '^ryoku$'; then
  if [[ -d /usr/share/plymouth/themes/omarchy ]]; then
    echo "  removing legacy /usr/share/plymouth/themes/omarchy"
    sudo rm -rf /usr/share/plymouth/themes/omarchy
  fi
fi

mkdir -p "$HOME/.local/state/ryoku"
touch "$MARKER"
