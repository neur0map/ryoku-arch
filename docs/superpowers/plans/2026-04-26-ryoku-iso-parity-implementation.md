# Ryoku ISO Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Ryoku ISO install and first boot match the intended live Ryoku system by enforcing branded boot/session parity, restoring the normal EFI UKI boot model, shipping boot-critical packages offline, and validating with a clean-room VM rebuild.

**Architecture:** Keep the current `archinstall -> chrooted Ryoku install` structure for now, but remove degraded success states so the second stage must produce the branded result. In parallel, move Ryoku toward the Omarchy model by making the repo the canonical source of shipped assets, by restoring the direct EFI UKI normal-boot path, and by embedding the boot-critical package overlay in the ISO's offline mirror rather than deferring it to AUR after install.

**Tech Stack:** Bash, archinstall, pacman/mkarchiso, Limine, UKI/mkinitcpio, Plymouth, SDDM, shell regression tests, QEMU/OVMF VM helpers.

---

## File Structure

**Files and responsibilities**

- `tests/iso-boot-parity.sh`
  Static regression checks for no degraded Limine fallback, no stale Omarchy UKI glob, no bogus pacman mirror, and required boot packages in the shipped package list.

- `tests/iso-offline-boot-overlay.sh`
  Static regression checks for the ISO builder wiring that creates and consumes the offline boot-package overlay.

- `default/sddm/pixel-rainyroom/**`
  Canonical shipped SDDM theme assets that must match the intended live system.

- `default/plymouth/**`
  Canonical shipped Plymouth assets used for the branded decrypt and boot sequence.

- `install/helpers/efi.sh`
  Shared helper functions for safe direct EFI UKI boot entry management so migrations and the direct-boot command stop drifting.

- `install/helpers/all.sh`
  Sources the new EFI helper module for all installer scripts.

- `bin/ryoku-config-direct-boot`
  Manual direct-boot command, fixed to find `ryoku*.efi` and to reuse the shared EFI helpers.

- `migrations/1777006624.sh`
  Independence-cutover migration, updated to stop deleting the normal Ryoku EFI UKI entry and to create/update it on supported firmware.

- `install/login/limine-snapper.sh`
  Boot-parity enforcement. This script must fail if the branded boot path cannot be produced.

- `install/login/sddm.sh`
  Graphical-login enforcement. This script must verify the shipped theme/session state before enabling SDDM.

- `install/ryoku-base.packages`
  Installed package contract. Boot-critical packages must appear here once they are supplied offline.

- `install/packaging/aur-core.sh`
  Post-install AUR-only packages that are not required for first-boot correctness. Boot-critical packages must be removed from this deferred list.

- `iso/builder/ryoku-boot-overlay.packages`
  Small manifest of AUR packages that must be built at ISO-build time and placed into the offline mirror.

- `iso/builder/build-boot-overlay.sh`
  Helper that clones and builds the boot-critical AUR packages during ISO creation and drops the artifacts into the ISO mirror cache.

- `iso/builder/build-iso.sh`
  ISO build orchestration. Must build the offline overlay before downloading official packages and must include those packages in the offline repo metadata.

- `iso/configs/airootfs/root/configurator`
  Generated archinstall JSON template. Must stop emitting the bogus GitHub pacman mirror.

- `install/config/hardware/network.sh`
  Deterministic first-boot wired networking for the installed VM.

### Task 1: Add boot-parity regression tests

**Files:**
- Create: `tests/iso-boot-parity.sh`
- Create: `tests/iso-offline-boot-overlay.sh`

- [ ] **Step 1: Write the failing parity test**

```bash
#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_no_stale_omarchy_direct_boot_glob() {
  if rg -n 'omarchy\*\.efi' "$ROOT_DIR/bin/ryoku-config-direct-boot" >/dev/null; then
    fail "ryoku-config-direct-boot still searches for omarchy*.efi"
  fi
}

assert_no_generic_limine_fallback() {
  if rg -n 'Continuing with the stock Limine config fallback|WARNING: limine-update not found' \
    "$ROOT_DIR/install/login/limine-snapper.sh" >/dev/null; then
    fail "limine-snapper.sh still accepts degraded generic-Limine success states"
  fi
}

assert_no_bogus_github_mirror() {
  if rg -n 'mirror\.github\.com/neur0map/ryoku-arch' \
    "$ROOT_DIR/iso/configs/airootfs/root/configurator" >/dev/null; then
    fail "configurator still emits the bogus GitHub pacman mirror"
  fi
}

assert_boot_packages_ship_in_base_manifest() {
  rg -n '^limine-mkinitcpio-hook$' "$ROOT_DIR/install/ryoku-base.packages" >/dev/null \
    || fail "install/ryoku-base.packages must include limine-mkinitcpio-hook"
  rg -n '^limine-snapper-sync$' "$ROOT_DIR/install/ryoku-base.packages" >/dev/null \
    || fail "install/ryoku-base.packages must include limine-snapper-sync"
}

assert_no_stale_omarchy_direct_boot_glob
assert_no_generic_limine_fallback
assert_no_bogus_github_mirror
assert_boot_packages_ship_in_base_manifest

echo "PASS: iso boot parity tests"
```

- [ ] **Step 2: Write the failing overlay-builder test**

```bash
#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_overlay_manifest_exists() {
  [[ -f $ROOT_DIR/iso/builder/ryoku-boot-overlay.packages ]] \
    || fail "missing iso/builder/ryoku-boot-overlay.packages"
}

assert_overlay_builder_exists() {
  [[ -f $ROOT_DIR/iso/builder/build-boot-overlay.sh ]] \
    || fail "missing iso/builder/build-boot-overlay.sh"
}

assert_iso_builder_invokes_overlay_builder() {
  rg -n 'build-boot-overlay\.sh|ryoku-boot-overlay\.packages' \
    "$ROOT_DIR/iso/builder/build-iso.sh" >/dev/null \
    || fail "build-iso.sh must build the offline boot overlay"
}

assert_aur_core_no_longer_owns_boot_packages() {
  if rg -n 'limine-mkinitcpio-hook|limine-snapper-sync' \
    "$ROOT_DIR/install/packaging/aur-core.sh" >/dev/null; then
    fail "aur-core.sh must not own boot-critical packages after overlay wiring"
  fi
}

assert_overlay_manifest_exists
assert_overlay_builder_exists
assert_iso_builder_invokes_overlay_builder
assert_aur_core_no_longer_owns_boot_packages

echo "PASS: iso offline boot overlay tests"
```

- [ ] **Step 3: Run tests to verify they fail**

Run:

```bash
/bin/bash tests/iso-boot-parity.sh
/bin/bash tests/iso-offline-boot-overlay.sh
```

Expected:

```text
FAIL: ryoku-config-direct-boot still searches for omarchy*.efi
FAIL: missing iso/builder/ryoku-boot-overlay.packages
```

- [ ] **Step 4: Add the test files**

```bash
git add tests/iso-boot-parity.sh tests/iso-offline-boot-overlay.sh
```

- [ ] **Step 5: Commit**

```bash
git commit -m "test: add iso parity guardrails"
```

### Task 2: Sync repo assets to the intended live system

**Files:**
- Modify: `default/sddm/pixel-rainyroom/**`
- Modify: `default/plymouth/**`

- [ ] **Step 1: Write the failing host-parity checks**

Run:

```bash
cmp -s default/sddm/pixel-rainyroom/Main.qml /usr/share/sddm/themes/pixel-rainyroom/Main.qml
printf 'sddm_main_match=%s\n' "$?"
cmp -s default/plymouth/ryoku.plymouth /usr/share/plymouth/themes/ryoku/ryoku.plymouth
printf 'plymouth_meta_match=%s\n' "$?"
```

Expected:

```text
sddm_main_match=1
plymouth_meta_match=0
```

- [ ] **Step 2: Replace the committed assets with the intended shipped copies**

```bash
rm -rf default/sddm/pixel-rainyroom
mkdir -p default/sddm
cp -a /usr/share/sddm/themes/pixel-rainyroom default/sddm/

rm -rf default/plymouth
mkdir -p default/plymouth
cp -a /usr/share/plymouth/themes/ryoku/. default/plymouth/
```

- [ ] **Step 3: Re-run the parity checks**

Run:

```bash
cmp -s default/sddm/pixel-rainyroom/Main.qml /usr/share/sddm/themes/pixel-rainyroom/Main.qml
printf 'sddm_main_match=%s\n' "$?"
cmp -s default/plymouth/ryoku.plymouth /usr/share/plymouth/themes/ryoku/ryoku.plymouth
printf 'plymouth_meta_match=%s\n' "$?"
```

Expected:

```text
sddm_main_match=0
plymouth_meta_match=0
```

- [ ] **Step 4: Stage the canonical asset updates**

```bash
git add default/sddm/pixel-rainyroom default/plymouth
```

- [ ] **Step 5: Commit**

```bash
git commit -m "assets: sync shipped sddm and plymouth themes"
```

### Task 3: Restore the normal EFI UKI boot policy

**Files:**
- Create: `install/helpers/efi.sh`
- Modify: `install/helpers/all.sh`
- Modify: `bin/ryoku-config-direct-boot`
- Modify: `migrations/1777006624.sh`

- [ ] **Step 1: Write the failing static checks**

Run:

```bash
rg -n 'omarchy\*\.efi|Ryoku\s+HD\(|never recreate one here' \
  bin/ryoku-config-direct-boot migrations/1777006624.sh
test -f install/helpers/efi.sh || echo MISSING_EFI_HELPER
```

Expected:

```text
bin/ryoku-config-direct-boot:26:uki_file=$(find /boot/EFI/Linux/ -name "omarchy*.efi" -printf "%f\n" 2>/dev/null | head -1)
migrations/1777006624.sh:79:# Drop any pre-existing Ryoku HD NVRAM entries that direct-boot the UKI.
MISSING_EFI_HELPER
```

- [ ] **Step 2: Add shared EFI helper functions**

Create `install/helpers/efi.sh`:

```bash
ryoku_efi_direct_boot_supported() {
  [[ -d /sys/firmware/efi ]] || return 1

  if [[ -f /sys/class/dmi/id/bios_vendor ]]; then
    local vendor
    vendor=$(</sys/class/dmi/id/bios_vendor)
    [[ $vendor =~ American[[:space:]]Megatrends ]] && return 1
    [[ $vendor =~ Apple ]] && return 1
  fi

  return 0
}

ryoku_find_uki_file() {
  find /boot/EFI/Linux/ -name "ryoku*.efi" -printf "%f\n" 2>/dev/null | sort | head -1
}

ryoku_remove_boot_entries_by_label() {
  local label="$1"
  command -v efibootmgr >/dev/null 2>&1 || return 0

  while IFS= read -r bootnum; do
    sudo efibootmgr -b "$bootnum" -B >/dev/null 2>&1 || true
  done < <(
    efibootmgr 2>/dev/null \
      | grep -E "^Boot[0-9A-Fa-f]{4}\*?[[:space:]]+$label([[:space:]]|$)" \
      | sed 's/^Boot\([0-9A-Fa-f]\{4\}\).*/\1/'
  )
}

ryoku_create_direct_boot_entry() {
  local uki_file="$1"
  local boot_source disk part

  boot_source=$(findmnt -n -o SOURCE /boot)
  disk=$(echo "$boot_source" | sed 's/p\?[0-9]*$//')
  part=$(echo "$boot_source" | grep -o 'p\?[0-9]*$' | sed 's/^p//')

  sudo efibootmgr --create \
    --disk "$disk" \
    --part "$part" \
    --label "Ryoku" \
    --loader "\\EFI\\Linux\\$uki_file"
}
```

Update `install/helpers/all.sh`:

```bash
source $RYOKU_INSTALL/helpers/chroot.sh
source $RYOKU_INSTALL/helpers/efi.sh
source $RYOKU_INSTALL/helpers/limine.sh
source $RYOKU_INSTALL/helpers/presentation.sh
source $RYOKU_INSTALL/helpers/errors.sh
source $RYOKU_INSTALL/helpers/logging.sh
```

- [ ] **Step 3: Rewire the direct-boot command and migration**

Update `bin/ryoku-config-direct-boot`:

```bash
#!/bin/bash

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"
source "$RYOKU_INSTALL/helpers/efi.sh"

if ! ryoku_efi_direct_boot_supported; then
  echo "Error: Direct EFI boot is not supported on this firmware" >&2
  exit 1
fi

if ! efibootmgr &>/dev/null; then
  echo "Error: efibootmgr is not available or not functional" >&2
  exit 1
fi

uki_file=$(ryoku_find_uki_file)

if [[ -z $uki_file ]]; then
  echo "Error: No Ryoku UKI found in /boot/EFI/Linux/" >&2
  exit 1
fi

if gum confirm "Setup direct boot (so snapshot booting must be done via bios)?"; then
  ryoku_remove_boot_entries_by_label "Ryoku"
  ryoku_create_direct_boot_entry "$uki_file"
fi
```

Replace the direct-entry removal block in `migrations/1777006624.sh` with:

```bash
source "$RYOKU_PATH/install/helpers/efi.sh"

if ryoku_efi_direct_boot_supported && command -v efibootmgr &>/dev/null; then
  uki_file=$(ryoku_find_uki_file)

  if [[ -n $uki_file ]]; then
    echo "  refreshing Ryoku EFI direct-boot entry"
    ryoku_remove_boot_entries_by_label "Ryoku"
    ryoku_create_direct_boot_entry "$uki_file"
  fi
fi
```

- [ ] **Step 4: Re-run the static checks**

Run:

```bash
rg -n 'omarchy\*\.efi|Ryoku\s+HD\(|never recreate one here' \
  bin/ryoku-config-direct-boot migrations/1777006624.sh
test -f install/helpers/efi.sh && echo EFI_HELPER_OK
```

Expected:

```text
EFI_HELPER_OK
```

- [ ] **Step 5: Commit**

```bash
git add install/helpers/efi.sh install/helpers/all.sh bin/ryoku-config-direct-boot migrations/1777006624.sh
git commit -m "boot: restore ryoku direct uki normal boot"
```

### Task 4: Make branded boot and graphical landing mandatory

**Files:**
- Modify: `install/login/limine-snapper.sh`
- Modify: `install/login/sddm.sh`

- [ ] **Step 1: Write the failing static checks**

Run:

```bash
rg -n 'Continuing with the stock Limine config fallback|WARNING: limine-update not found' \
  install/login/limine-snapper.sh
rg -n 'systemctl enable sddm.service' install/login/sddm.sh
```

Expected:

```text
install/login/limine-snapper.sh:3:    echo "WARNING: limine-snapper-sync and limine-mkinitcpio-hook are unavailable."
install/login/limine-snapper.sh:124:  echo "WARNING: limine-update not found (limine-snapper-sync not installed)."
install/login/sddm.sh:18:sudo systemctl enable sddm.service
```

- [ ] **Step 2: Replace warning fallbacks with production-fatal checks**

In `install/login/limine-snapper.sh`, replace the opening package block with:

```bash
if ! command -v limine &>/dev/null; then
  echo "Error: limine package missing; production ISO boot parity is impossible" >&2
  exit 1
fi

if ! sudo pacman -Q limine-snapper-sync limine-mkinitcpio-hook >/dev/null 2>&1; then
  echo "Error: missing limine-snapper-sync/limine-mkinitcpio-hook; production ISO boot parity is impossible" >&2
  exit 1
fi

if ! command -v limine-update >/dev/null 2>&1; then
  echo "Error: limine-update missing; production ISO boot parity is impossible" >&2
  exit 1
fi
```

Replace the fallback branch and trailing warning path with:

```bash
  if [[ $limine_config != "/boot/limine.conf" ]] && [[ -f $limine_config ]]; then
    sudo rm "$limine_config"
  fi
  sudo cp $RYOKU_PATH/default/limine/limine.conf /boot/limine.conf

echo "Re-enabling mkinitcpio hooks..."
sudo mkinitcpio -P
sudo limine-update

[[ -f /boot/EFI/Linux/ryoku_linux.efi ]] || {
  echo "Error: missing /boot/EFI/Linux/ryoku_linux.efi after limine-update" >&2
  exit 1
}

grep -q '^/+Ryoku' /boot/limine.conf || {
  echo "Error: /boot/limine.conf is missing Ryoku branded entries" >&2
  exit 1
}
```

In `install/login/sddm.sh`, add pre-enable verification immediately before enabling SDDM:

```bash
[[ -f /usr/share/sddm/themes/pixel-rainyroom/metadata.desktop ]] || {
  echo "Error: bundled pixel-rainyroom theme is missing from /usr/share/sddm/themes" >&2
  exit 1
}

[[ -f /usr/share/wayland-sessions/hyprland-uwsm.desktop ]] || {
  echo "Error: hyprland-uwsm session file is missing; graphical login would land incorrectly" >&2
  exit 1
}

sudo systemctl enable sddm.service
sudo systemctl set-default graphical.target
```

- [ ] **Step 3: Re-run the static checks**

Run:

```bash
rg -n 'Continuing with the stock Limine config fallback|WARNING: limine-update not found' \
  install/login/limine-snapper.sh
rg -n 'production ISO boot parity is impossible|pixel-rainyroom|hyprland-uwsm' \
  install/login/limine-snapper.sh install/login/sddm.sh
```

Expected:

```text
install/login/limine-snapper.sh:3:    echo "Error: missing limine-snapper-sync/limine-mkinitcpio-hook; production ISO boot parity is impossible" >&2
install/login/sddm.sh:17:[[ -f /usr/share/sddm/themes/pixel-rainyroom/metadata.desktop ]] || {
install/login/sddm.sh:22:[[ -f /usr/share/wayland-sessions/hyprland-uwsm.desktop ]] || {
```

- [ ] **Step 4: Run the regression tests**

Run:

```bash
/bin/bash tests/limine-splash-fallback.sh
/bin/bash tests/iso-boot-parity.sh
```

Expected:

```text
PASS: limine splash fallback tests
PASS: iso boot parity tests
```

- [ ] **Step 5: Commit**

```bash
git add install/login/limine-snapper.sh install/login/sddm.sh
git commit -m "install: require branded boot and graphical parity"
```

### Task 5: Build and consume an offline boot-package overlay

**Files:**
- Create: `iso/builder/ryoku-boot-overlay.packages`
- Create: `iso/builder/build-boot-overlay.sh`
- Modify: `iso/builder/build-iso.sh`
- Modify: `install/ryoku-base.packages`
- Modify: `install/packaging/aur-core.sh`
- Modify: `iso/configs/airootfs/root/configurator`
- Modify: `install/config/hardware/network.sh`

- [ ] **Step 1: Write the failing static checks**

Run:

```bash
test -f iso/builder/ryoku-boot-overlay.packages || echo MISSING_OVERLAY_MANIFEST
test -f iso/builder/build-boot-overlay.sh || echo MISSING_OVERLAY_BUILDER
rg -n 'mirror\.github\.com/neur0map/ryoku-arch|limine-mkinitcpio-hook|limine-snapper-sync' \
  iso/configs/airootfs/root/configurator install/packaging/aur-core.sh install/ryoku-base.packages
```

Expected:

```text
MISSING_OVERLAY_MANIFEST
MISSING_OVERLAY_BUILDER
iso/configs/airootfs/root/configurator:423:            {"url": "https://mirror.github.com/neur0map/ryoku-arch/\$repo/os/\$arch"},
install/packaging/aur-core.sh:37:  limine-mkinitcpio-hook
```

- [ ] **Step 2: Add the overlay manifest and builder**

Create `iso/builder/ryoku-boot-overlay.packages`:

```text
limine-mkinitcpio-hook
limine-snapper-sync
```

Create `iso/builder/build-boot-overlay.sh`:

```bash
#!/bin/bash

set -euo pipefail

packages_file="$1"
output_dir="$2"
build_root=$(mktemp -d)
trap 'rm -rf "$build_root"' EXIT

pacman --noconfirm -Sy --needed base-devel git sudo

id -u builder >/dev/null 2>&1 || useradd -m builder
printf '%s\n' 'builder ALL=(ALL) NOPASSWD: ALL' >/etc/sudoers.d/90-builder
chmod 440 /etc/sudoers.d/90-builder

while IFS= read -r pkg; do
  [[ -n $pkg ]] || continue
  work_dir="$build_root/$pkg"

  sudo -u builder git clone --depth=1 "https://aur.archlinux.org/${pkg}.git" "$work_dir"
  pushd "$work_dir" >/dev/null
  sudo -u builder env PKGDEST="$output_dir" makepkg --syncdeps --clean --cleanbuild --noconfirm
  popd >/dev/null
done < "$packages_file"
```

- [ ] **Step 3: Wire the overlay into the ISO and installer**

In `install/ryoku-base.packages`, add:

```text
limine-mkinitcpio-hook
limine-snapper-sync
```

In `install/packaging/aur-core.sh`, remove:

```text
  limine-mkinitcpio-hook
```

In `iso/configs/airootfs/root/configurator`, replace the mirror block with:

```json
    "mirror_config": {
        "custom_repositories": [],
        "custom_servers": [
            {"url": "https://geo.mirror.pkgbuild.com/$repo/os/$arch"},
            {"url": "https://mirror.rackspace.com/archlinux/$repo/os/$arch"}
        ],
        "mirror_regions": {},
        "optional_repositories": []
    },
```

In `install/config/hardware/network.sh`, append a verification block:

```bash
sudo systemctl is-enabled systemd-networkd.service >/dev/null 2>&1 || {
  echo "Error: systemd-networkd.service did not end up enabled" >&2
  exit 1
}

sudo systemctl is-enabled systemd-resolved.service >/dev/null 2>&1 || {
  echo "Error: systemd-resolved.service did not end up enabled" >&2
  exit 1
}

[[ -L /etc/resolv.conf ]] || {
  echo "Error: /etc/resolv.conf must be a systemd-resolved symlink for first-boot VM DNS" >&2
  exit 1
}
```

In `iso/builder/build-iso.sh`, add the overlay build and filtering logic after the repo copy:

```bash
mapfile -t overlay_packages < <(grep -v '^#' /builder/ryoku-boot-overlay.packages | grep -v '^$')
/bin/bash /builder/build-boot-overlay.sh /builder/ryoku-boot-overlay.packages "$offline_mirror_dir"

mapfile -t all_packages < <(
  {
    cat "$build_cache_dir/packages.x86_64"
    grep -v '^#' "$build_cache_dir/airootfs/root/ryoku/install/ryoku-base.packages" | grep -v '^$'
    grep -v '^#' /builder/archinstall.packages | grep -v '^$'
  } | awk 'NF { print }'
)

official_packages=()
for pkg in "${all_packages[@]}"; do
  skip=0
  for overlay_pkg in "${overlay_packages[@]}"; do
    if [[ $pkg == "$overlay_pkg" ]]; then
      skip=1
      break
    fi
  done
  (( skip == 0 )) && official_packages+=("$pkg")
done

pacman --config /configs/pacman-online-${RYOKU_MIRROR}.conf \
  --noconfirm -Syw "${official_packages[@]}" \
  --cachedir "$offline_mirror_dir/" --dbpath /tmp/offlinedb

repo-add --new "$offline_mirror_dir/offline.db.tar.gz" "$offline_mirror_dir/"*.pkg.tar.zst
```

- [ ] **Step 4: Re-run the static checks and regression tests**

Run:

```bash
/bin/bash tests/iso-offline-boot-overlay.sh
/bin/bash tests/iso-boot-parity.sh
```

Expected:

```text
PASS: iso offline boot overlay tests
PASS: iso boot parity tests
```

- [ ] **Step 5: Commit**

```bash
git add iso/builder/ryoku-boot-overlay.packages iso/builder/build-boot-overlay.sh iso/builder/build-iso.sh install/ryoku-base.packages install/packaging/aur-core.sh iso/configs/airootfs/root/configurator install/config/hardware/network.sh
git commit -m "iso: embed offline boot overlay and clean install inputs"
```

### Task 6: Rebuild from a clean room and replace broken artifacts

**Files:**
- Verify: `iso/release/*.iso`
- Verify: `/tmp/ryoku-iso-boot.qcow2`
- Verify: `/tmp/OVMF_VARS.4m.fd`
- Verify: `iso/vm-saves/*`
- Verify: `~/.cache/ryoku/iso_2026-04-26`

- [ ] **Step 1: Write the failing artifact-state check**

Run:

```bash
ls -1 iso/release 2>/dev/null || true
test -f /tmp/ryoku-iso-boot.qcow2 && echo TMP_VM_DISK_PRESENT
test -f /tmp/OVMF_VARS.4m.fd && echo TMP_OVMF_PRESENT
find iso/vm-saves -mindepth 1 -maxdepth 1 2>/dev/null | sed -n '1,20p'
test -d "$HOME/.cache/ryoku/iso_2026-04-26" && echo ISO_CACHE_PRESENT
```

Expected:

```text
TMP_VM_DISK_PRESENT
TMP_OVMF_PRESENT
ISO_CACHE_PRESENT
```

- [ ] **Step 2: Remove stale ISO, VM, and cache artifacts**

Run:

```bash
rm -f iso/release/*.iso
rm -f /tmp/ryoku-iso-boot.qcow2 /tmp/OVMF_VARS.4m.fd
rm -rf iso/vm-saves/*
rm -rf "$HOME/.cache/ryoku/iso_2026-04-26"
```

- [ ] **Step 3: Build a fresh ISO with the current checkout**

Run:

```bash
/bin/bash iso/bin/ryoku-iso-make --local-source --no-boot-offer
```

Expected:

```text
... mkarchiso output ...
... release/<new-iso-name>.iso created ...
```

- [ ] **Step 4: Boot the new ISO into a fresh VM and validate the release contract**

Run:

```bash
/bin/bash iso/bin/ryoku-iso-boot "$(ls -t iso/release/*.iso | head -n1)"
```

Expected manual validation:

```text
1. Installed system normal boot uses the intended Ryoku production path.
2. Branded decrypt prompt appears.
3. pixel-rainyroom SDDM appears.
4. Logging in reaches the Ryoku session.
5. Installed VM gets NAT ethernet on first boot.
```

- [ ] **Step 5: Commit the verification-support changes**

```bash
git add tests/iso-boot-parity.sh tests/iso-offline-boot-overlay.sh default/sddm/pixel-rainyroom default/plymouth install/helpers/efi.sh install/helpers/all.sh bin/ryoku-config-direct-boot migrations/1777006624.sh install/login/limine-snapper.sh install/login/sddm.sh iso/builder/ryoku-boot-overlay.packages iso/builder/build-boot-overlay.sh iso/builder/build-iso.sh install/ryoku-base.packages install/packaging/aur-core.sh iso/configs/airootfs/root/configurator install/config/hardware/network.sh
git commit -m "iso: restore branded offline boot parity"
```

## Self-Review

### Spec coverage

- `repo becomes canonical`: covered by Task 2.
- `normal production boot matches Omarchy model`: covered by Task 3.
- `branded boot path is mandatory`: covered by Task 4.
- `offline boot-critical package parity`: covered by Task 5.
- `clean-room VM validation and artifact replacement`: covered by Task 6.
- `bad generated pacman mirror and VM ethernet`: covered by Task 5.

### Placeholder scan

- No `TODO`/`TBD` markers remain.
- Every file path is explicit.
- Every code-changing step contains concrete code or exact shell content.
- Every validation step includes exact commands and expected outcomes.

### Common-sense gap review

- The plan does not assume direct EFI boot is safe on all firmware. The shared helper keeps the existing Apple/American Megatrends exclusions.
- The plan does not delete Limine entirely. Limine remains for recovery/snapshots while the normal path returns to direct EFI UKI boot.
- The plan does not require a full Ryoku hosted package repo first. It uses an embedded ISO overlay for boot-critical packages so parity can land before repo/keyring infrastructure exists.
- The plan explicitly cleans stale ISO, VM, and cache artifacts before the final validation so old broken state cannot masquerade as success.
