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

# Find a UEFI fallback HD entry if present, so we have a safety net.
fallback=$(efibootmgr 2>/dev/null \
  | grep -E '^Boot[0-9]{4}\*? UEFI OS\s+HD\(' \
  | sed 's/^Boot\([0-9]\{4\}\).*/\1/' \
  | head -1)

# Step 1: set BootOrder with Limine first so that even if the Ryoku
# removal below fails partway, the next boot still lands on Limine.
current_order=$(efibootmgr 2>/dev/null | awk '/^BootOrder/{print $2}')
IFS=',' read -ra order_arr <<< "$current_order"

new_order=("$limine_entry")
[[ -n $fallback && $fallback != "$limine_entry" ]] && new_order+=("$fallback")

# Gather the numbers of all the Ryoku HD entries we intend to delete,
# so we can skip them when rebuilding BootOrder too.
mapfile -t ryoku_entries < <(efibootmgr 2>/dev/null \
  | grep -E '^Boot[0-9]{4}\*? Ryoku\s+HD\(' \
  | sed 's/^Boot\([0-9]\{4\}\).*/\1/')

is_removed_ryoku() {
  local num=$1
  local r
  for r in "${ryoku_entries[@]}"; do
    [[ $num == "$r" ]] && return 0
  done
  return 1
}

for entry in "${order_arr[@]}"; do
  [[ $entry == "$limine_entry" ]] && continue
  [[ -n $fallback && $entry == "$fallback" ]] && continue
  is_removed_ryoku "$entry" && continue
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

# Step 2: drop the direct-UKI Ryoku entries. The running kernel stays
# up even if its own NVRAM entry is deleted; only next boot behaviour
# is affected, and BootOrder above already ensures that lands on Limine.
for ryoku_num in "${ryoku_entries[@]}"; do
  echo "  removing direct-UKI entry Boot$ryoku_num"
  sudo efibootmgr -b "$ryoku_num" -B >/dev/null 2>&1 || true
done

mkdir -p "$HOME/.local/state/ryoku"
touch "$MARKER"
