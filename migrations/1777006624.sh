echo "Rename UKI from omarchy_linux.efi to ryoku_linux.efi"

MARKER="$HOME/.local/state/ryoku/independence-cutover.uki.done"

if [[ -f $MARKER ]]; then
  exit 0
fi

if ! command -v limine &>/dev/null; then
  echo "  limine not installed, nothing to do"
  mkdir -p "$HOME/.local/state/ryoku"
  touch "$MARKER"
  exit 0
fi

if [[ ! -f /etc/default/limine ]]; then
  echo "  /etc/default/limine not found, skipping"
  mkdir -p "$HOME/.local/state/ryoku"
  touch "$MARKER"
  exit 0
fi

if ! grep -q '^ENABLE_UKI=yes' /etc/default/limine; then
  echo "  UKI disabled on this host, nothing to rename"
  mkdir -p "$HOME/.local/state/ryoku"
  touch "$MARKER"
  exit 0
fi

# If the live config is already renamed, we still want to make sure the
# EFI entry and old UKI were cleaned up. Otherwise snapshot and migrate.
NEEDS_RENAME=no
if grep -q '^CUSTOM_UKI_NAME="omarchy"' /etc/default/limine; then
  NEEDS_RENAME=yes
fi
if grep -q '^TARGET_OS_NAME="Omarchy"' /etc/default/limine; then
  NEEDS_RENAME=yes
fi

if [[ $NEEDS_RENAME == yes ]]; then
  echo "  creating snapshot before touching the bootloader"
  ryoku-snapshot create || {
    echo "  snapshot failed; refusing to rewrite /etc/default/limine" >&2
    exit 1
  }

  echo "  updating /etc/default/limine (TARGET_OS_NAME + CUSTOM_UKI_NAME)"
  sudo sed -i \
    -e 's/^TARGET_OS_NAME="Omarchy"/TARGET_OS_NAME="Ryoku"/' \
    -e 's/^CUSTOM_UKI_NAME="omarchy"/CUSTOM_UKI_NAME="ryoku"/' \
    /etc/default/limine

  echo "  regenerating UKI with new name"
  if ! sudo limine-mkinitcpio; then
    echo "  limine-mkinitcpio failed; leaving old UKI in place" >&2
    exit 1
  fi
fi

# Verify the new UKI exists before we touch the old one.
if ! compgen -G "/boot/EFI/Linux/ryoku_linux.efi" >/dev/null; then
  echo "  expected /boot/EFI/Linux/ryoku_linux.efi to exist, aborting cleanup" >&2
  exit 1
fi

# Refresh /boot/limine.conf so the "Ryoku Bootloader" branding lands and
# limine-update re-adds the entries that point to ryoku_linux.efi.
if grep -q '^interface_branding: Omarchy Bootloader' /boot/limine.conf 2>/dev/null; then
  echo "  refreshing /boot/limine.conf branding"
  sudo cp -f "$RYOKU_PATH/default/limine/limine.conf" /boot/limine.conf
fi

echo "  running limine-update"
sudo limine-update

echo "  running limine-snapper-sync"
sudo limine-snapper-sync || true

# Drop any pre-existing Ryoku HD NVRAM entries that direct-boot the UKI.
# Limine loads the UKI for us; a separate UEFI entry that bypasses Limine
# hides the boot menu and breaks framebuffer handoff on some firmware,
# which is why we never recreate one here.
if command -v efibootmgr &>/dev/null && [[ -d /sys/firmware/efi ]]; then
  current=$(efibootmgr 2>/dev/null | awk '/^BootCurrent/{print $2}')
  while IFS= read -r bootnum; do
    [[ $bootnum == "$current" ]] && continue
    sudo efibootmgr -b "$bootnum" -B >/dev/null 2>&1 || true
  done < <(efibootmgr 2>/dev/null \
    | grep -E "^Boot[0-9]{4}\*? Ryoku\s+HD\(" \
    | sed 's/^Boot\([0-9]\{4\}\).*/\1/')
fi

# Only drop the legacy UKI once everything above succeeded.
if [[ -f /boot/EFI/Linux/omarchy_linux.efi ]]; then
  echo "  removing legacy /boot/EFI/Linux/omarchy_linux.efi"
  sudo rm -f /boot/EFI/Linux/omarchy_linux.efi
fi

mkdir -p "$HOME/.local/state/ryoku"
touch "$MARKER"
