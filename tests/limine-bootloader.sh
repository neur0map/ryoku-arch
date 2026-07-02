#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# fixture test for the bootloader step's limine.conf handling: the config must
# land at the ESP root (/boot/limine.conf, the one location limine-entry-tool
# manages -- anything else shadows the generated kernel + snapshot entries),
# default_entry must match the menu shape (1 = flat placeholder, 2 = first UKI
# inside the /+Ryoku tree), and the post-AUR promote must retire the flat
# entry without touching foreign entries. all hermetic: dry-run for the
# installer paths, a temp file for the promote surgery.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="$here/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

# shellcheck source=../installation/backend/lib/common.sh
source "$repo/installation/backend/lib/common.sh"
# shellcheck source=../installation/backend/lib/bootloader.sh
source "$repo/installation/backend/lib/bootloader.sh"

export RYOKU_REPO="$repo"
export RYOKU_DRYRUN=1
CMDLINE="root=UUID=test-uuid rootflags=subvol=@ rw"

# --- with_entry: flat menu, ESP-root path, bootable default ----------------
out="$(ryoku_boot_limine_conf with_entry)"
grep -qF 'DRYRUN: write /mnt/boot/limine.conf:' <<<"$out" \
  || fail "with_entry must write /boot/limine.conf (the ESP root), nothing else"
grep -qF 'default_entry: 1' <<<"$out" \
  || fail "flat menu must default to entry 1 (there is no tree directory to skip)"
grep -qF 'default_entry: 2' <<<"$out" \
  && fail "flat menu left default_entry: 2 (would autoboot a second entry, e.g. Windows)"
grep -qF '/Ryoku Linux' <<<"$out" || fail "with_entry missing the flat kernel entry"
grep -qF "cmdline: $CMDLINE quiet splash" <<<"$out" || fail "flat entry missing the real cmdline"
grep -qF 'rm -f' <<<"$out" || fail "with_entry must remove the shadowing config candidates"
grep -qF '/mnt/boot/limine/limine.conf' <<<"$out" \
  || fail "the shadow candidate /boot/limine/limine.conf is not in the cleanup list"

# --- branding_only: tool-managed menu keeps default_entry: 2 ---------------
out="$(ryoku_boot_limine_conf branding_only)"
grep -qF 'default_entry: 2' <<<"$out" \
  || fail "tool-managed menu must default past the /+Ryoku directory to the newest UKI"
grep -qF '/Ryoku Linux' <<<"$out" && fail "branding_only must not carry the placeholder entry"

# --- install_efi: the tool-refreshed binary path, never limine.efi ---------
# shellcheck disable=SC2034  # consumed by the sourced ryoku_boot_install_efi
ESP_DEV=/dev/vda1 RYOKU_DISK=/dev/vda
out="$(ryoku_boot_install_efi)"
grep -qF '/mnt/boot/EFI/limine/limine_x64.efi' <<<"$out" \
  || fail "EFI binary must land on limine_x64.efi (the path limine-install refreshes on upgrades)"
grep -qF '\EFI\limine\limine_x64.efi' <<<"$out" \
  || fail "NVRAM entry must point at limine_x64.efi so the tool's dedup recognizes it"
grep -qF '/mnt/boot/EFI/limine/limine.efi ' <<<"$out" \
  && fail "the stale hand-copied limine.efi path is back"

# --- promote: drop the flat entry, repoint the default, keep foreigners ----
unset RYOKU_DRYRUN
conf="$tmp/limine.conf"
cat >"$conf" <<'EOF'
timeout: 3
default_entry: 1
interface_branding: Ryoku Bootloader

/Ryoku Linux
    protocol: linux
    kernel_path: boot():/vmlinuz-linux
    cmdline: root=UUID=x rw quiet splash
    module_path: boot():/initramfs-linux.img

/+Ryoku
    comment: Ryoku
//linux
    protocol: efi
    path: boot():/EFI/Linux/ryoku_linux.efi

# >>> ryoku-windows-entry (managed) >>>
/Windows
    comment: Boot into Windows
    protocol: efi_chainload
    path: uuid(abc):/EFI/Microsoft/Boot/bootmgfw.efi
# <<< ryoku-windows-entry (managed) <<<
EOF

ryoku_boot_limine_promote "$conf"
grep -qF '/Ryoku Linux' "$conf" && fail "promote left the flat placeholder entry"
grep -qF 'kernel_path: boot():/vmlinuz-linux' "$conf" && fail "promote left the placeholder's options"
grep -qxF 'default_entry: 2' "$conf" || fail "promote must repoint default_entry at the tree's first UKI"
grep -qxF '/+Ryoku' "$conf" || fail "promote clobbered the tool's boot tree"
grep -qxF '/Windows' "$conf" || fail "promote clobbered the Windows chainload entry"
grep -qF 'interface_branding: Ryoku Bootloader' "$conf" || fail "promote clobbered the branding"

# promote is idempotent: a second run changes nothing.
cp "$conf" "$tmp/before.conf"
ryoku_boot_limine_promote "$conf"
diff -q "$tmp/before.conf" "$conf" >/dev/null || fail "second promote changed the file"

echo "limine-bootloader: all checks passed"
