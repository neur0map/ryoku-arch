echo "Refresh /boot/limine.conf with Greek Noir palette + clean stale NVRAM entries"

MARKER="$HOME/.local/state/ryoku/independence-cutover.limine-palette.done"

if [[ -f $MARKER ]]; then
  exit 0
fi

if ! command -v limine &>/dev/null; then
  mkdir -p "$HOME/.local/state/ryoku"
  touch "$MARKER"
  exit 0
fi

if [[ -f /boot/limine.conf ]] && grep -q '^term_palette: 15161e' /boot/limine.conf; then
  echo "  swapping limine terminal palette"
  sudo cp -f "$RYOKU_PATH/default/limine/limine.conf" /boot/limine.conf
  sudo limine-update
fi

# Drop NVRAM boot entries labelled "Omarchy" so the UEFI boot menu does
# not advertise the previous brand. Only touch entries that are not the
# currently active boot; never remove the one we booted from.
if command -v efibootmgr &>/dev/null && [[ -d /sys/firmware/efi ]]; then
  current=$(efibootmgr 2>/dev/null | awk '/^BootCurrent/{print $2}')
  while IFS= read -r bootnum; do
    [[ $bootnum == "$current" ]] && continue
    echo "  removing stale NVRAM entry Boot$bootnum (Omarchy)"
    sudo efibootmgr -b "$bootnum" -B >/dev/null 2>&1 || true
  done < <(efibootmgr 2>/dev/null | grep -E "^Boot[0-9]{4}\*? Omarchy" | sed 's/^Boot\([0-9]\{4\}\).*/\1/')
fi

mkdir -p "$HOME/.local/state/ryoku"
touch "$MARKER"
