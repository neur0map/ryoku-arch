echo "Make Limine the sole primary UEFI boot entry"

MARKER="$HOME/.local/state/ryoku/independence-cutover.bootorder.done"

if [[ -f $MARKER ]]; then
  exit 0
fi

if ! command -v efibootmgr &>/dev/null || [[ ! -d /sys/firmware/efi ]]; then
  mkdir -p "$HOME/.local/state/ryoku"
  touch "$MARKER"
  exit 0
fi

# Find the Limine HD entry (real file path, not the VenHw placeholder)
limine_entry=$(efibootmgr 2>/dev/null \
  | grep -E '^Boot[0-9]{4}\*? Limine\s+HD\(' \
  | sed 's/^Boot\([0-9]\{4\}\).*/\1/' \
  | head -1)

if [[ -z $limine_entry ]]; then
  echo "  WARNING: no real Limine boot entry found; refusing to touch BootOrder"
  exit 0
fi

# Remove the standalone Ryoku UKI entries so firmware never attempts to
# direct-boot the UKI. Limine knows how to load it; a UEFI entry that
# bypasses Limine only hides the menu and breaks framebuffer handoff on
# some hardware.
while IFS= read -r ryoku_num; do
  current=$(efibootmgr 2>/dev/null | awk '/^BootCurrent/{print $2}')
  if [[ $ryoku_num == "$current" ]]; then
    echo "  skipping removal of Boot$ryoku_num (currently active)"
    continue
  fi
  echo "  removing direct-UKI entry Boot$ryoku_num"
  sudo efibootmgr -b "$ryoku_num" -B >/dev/null 2>&1 || true
done < <(efibootmgr 2>/dev/null \
  | grep -E '^Boot[0-9]{4}\*? Ryoku\s+HD\(' \
  | sed 's/^Boot\([0-9]\{4\}\).*/\1/')

# Pick up the UEFI fallback entry if present, so we have a safety net.
fallback=$(efibootmgr 2>/dev/null \
  | grep -E '^Boot[0-9]{4}\*? UEFI OS\s+HD\(' \
  | sed 's/^Boot\([0-9]\{4\}\).*/\1/' \
  | head -1)

# Rebuild BootOrder: Limine first, then fallback, then everything else
# except the entries we already removed. Preserve non-Ryoku entries so
# we do not nuke the user's other OS shortcuts.
current_order=$(efibootmgr 2>/dev/null | awk '/^BootOrder/{print $2}')
IFS=',' read -ra order_arr <<< "$current_order"

new_order=("$limine_entry")
[[ -n $fallback && $fallback != "$limine_entry" ]] && new_order+=("$fallback")

for entry in "${order_arr[@]}"; do
  [[ $entry == "$limine_entry" ]] && continue
  [[ -n $fallback && $entry == "$fallback" ]] && continue
  # Skip entries that no longer exist after the removals above
  if ! efibootmgr 2>/dev/null | grep -qE "^Boot${entry}\*? "; then
    continue
  fi
  new_order+=("$entry")
done

joined=$(IFS=','; echo "${new_order[*]}")
if [[ $joined != "$current_order" ]]; then
  echo "  setting BootOrder: $joined"
  sudo efibootmgr -o "$joined" >/dev/null 2>&1 || true
fi

mkdir -p "$HOME/.local/state/ryoku"
touch "$MARKER"
