# Installing on real hardware

VMs install clean. Metal is where installers die, and the failures cluster into
a handful of classes that a live-USB installer has to handle or explain. This is
the durable home of that research: per class, the symptom a user sees, the cause,
what the Ryoku installer now does automatically, and what the user still has to
do in firmware or Windows when automation cannot reach it.

The backend that implements the automatic half lives in
`installation/backend/lib/`; the front-end gates in `installation/tui/`.

## Contents

- [Intel VMD / RST hides the NVMe](#intel-vmd--rst-hides-the-nvme)
- [Secure Boot vs unsigned Limine](#secure-boot-vs-unsigned-limine)
- [NVIDIA black or garbled screen](#nvidia-black-or-garbled-screen)
- [Windows dual-boot](#windows-dual-boot)
- [Broadcom Wi-Fi](#broadcom-wi-fi)
- [RTC clock skew vs pacman signatures](#rtc-clock-skew-vs-pacman-signatures)
- [NVRAM-readonly firmware](#nvram-readonly-firmware)
- [Ventoy and other loop-mounted media](#ventoy-and-other-loop-mounted-media)
- [Slow or flaky USB media](#slow-or-flaky-usb-media)

## Intel VMD / RST hides the NVMe

**Symptom.** The target-disk step is empty, or the install completes and then
drops to an emergency shell on first reboot because it cannot find its own root.
Common on Intel laptops.

**Cause.** Intel Volume Management Device (the "VMD" / RST mode in firmware)
hides the NVMe behind a controller the kernel cannot see without the `vmd`
module. If the module is needed on the live system, it is needed in the installed
initramfs too, or the target loses its own disk at boot.

**What the installer does.** When the live kernel has VMD loaded
(`/sys/module/vmd`), `bootloader.sh` writes `MODULES+=(vmd)` into the target
initramfs before it is built, so both the UKI and the `mkinitcpio -P` paths bake
it in. If the disk list is empty, the TUI's disk hint names VMD as the likely
cause instead of a generic "no disk".

**What the user must do.** If the live installer itself sees no disk, the live
kernel did not load `vmd`. On a Ryoku-only machine, switch the firmware storage
mode from RST/VMD to AHCI and retry. On a machine that also runs Windows, do not
switch to AHCI (Windows installed under VMD will fail to boot): instead leave VMD
on and boot the installer so the `vmd` module loads and gets carried into the
target automatically.

## Secure Boot vs unsigned Limine

**Symptom.** The installer refuses to start with a "Secure Boot is enabled"
message; or, if that gate is bypassed, the installed system dies at a security
violation on first boot.

**Cause.** Limine ships unsigned. Firmware enforcing Secure Boot will not run an
unsigned bootloader.

**What the installer does.** The TUI blocks the Review screen when
`secureBootEnabled()` reports Secure Boot on, and the backend's preflight dies
before touching the disk, both with "disable Secure Boot in firmware setup"
guidance. `RYOKU_ALLOW_SECUREBOOT=1` overrides it for a user who has enrolled
their own keys.

**What the user must do.** Enter firmware setup, disable Secure Boot, reboot the
installer. Set the override only if you have enrolled your own keys and know
Limine will pass.

## NVIDIA black or garbled screen

**Symptom.** The screen goes black or garbled at boot, live or installed, on some
NVIDIA and hybrid laptops.

**Cause.** Kernel mode-setting and the NVIDIA modeset handoff. Some panels need
mode-setting off to reach the installer at all; the installed NVIDIA system needs
it on.

**What the installer does.** The live ISO's default entry boots with KMS on, and
ships a "safe graphics" entry that adds `nomodeset` for machines that come up
black. The installed `amd-nvidia` profile gets `nvidia_drm.modeset=1` on its
kernel cmdline (`ryoku_cmdline`), and the NVIDIA early-KMS `MODULES` drop-in is
written only when the driver module actually built.

**What the user must do.** If the live screen is black or garbled, pick the
**safe graphics (nomodeset)** boot entry. The installed system is configured for
NVIDIA already; if it comes up black, boot the Limine fallback and add `nomodeset`
to the cmdline for that boot to get in and investigate.

## Windows dual-boot

**Symptom.** "Installation alongside Windows failed" partway through (out of
space); or not enough free space to start; or Windows will not boot after the
install.

**Cause.** The OEM ESP is typically 100-260 MiB, far too small to hold our
kernel, initramfs, and UKIs (out of space mid-`pacstrap` or at `mkinitcpio`), and
reusing it would overwrite Windows' own boot loader.

**What the installer does.** The `alongside` strategy never touches the Windows
ESP. It creates a dedicated Ryoku ESP (partlabel `ryokuboot`) plus the Btrfs root
(partlabel `ryoku`) in the largest contiguous free region, and proves both are
brand new partitions before formatting. Partitions labeled exactly
`ryoku`/`ryokuboot` (leftovers of a prior failed run) abort the install unless
`RYOKU_RECLAIM_LEFTOVERS=1` (the TUI's typed `ERASE` ack) deletes only the
unmounted ones, so re-runs never stack; a mounted match is always left alone. It
adds a Windows chainload entry so Windows stays in the Limine menu, and the
first reboot targets the installed disk. It needs `20 + swap + ESP` GiB of
contiguous free space.

**What the user must do.**

- **Make room first.** Shrink the Windows C: partition from within Windows (Disk
  Management -> Shrink Volume), leaving enough contiguous free space. Shrinking
  from Windows is the safest way; the installer deliberately never resizes an
  existing partition.
- **BitLocker.** Suspend BitLocker in Windows before you install. Two things trip
  it: changing the partition table can force a recovery-key prompt on the next
  Windows boot, and chainloading through Limine changes the measured boot path,
  so a BitLocker-on machine prompts for the recovery key on every chainloaded
  boot until BitLocker is suspended and re-sealed (Windows re-seals on its own
  next boot). Suspend it before installing, or skip the chainload and boot
  Windows from the firmware boot menu, whose loader path is unchanged and never
  prompts.
- **Fast Startup.** Disable Windows Fast Startup (hybrid shutdown). It leaves the
  disk in a hibernated state that can lock filesystems and confuse dual-boot.
- **Boot order after install.** The installer registers its NVRAM entry and sets
  it first for the next boot. If the firmware resets the order (or ignores NVRAM,
  see below), enter firmware setup and put the Ryoku / Limine entry first.
- **If the Limine chainload boot-loops.** Some firmware will not chainload
  Windows cleanly and loops back to the menu. The Windows loader and its own
  NVRAM entry are untouched, so pick **Windows Boot Manager** directly from the
  firmware boot menu (usually F12 / F9 / Esc at power-on) to boot Windows; use
  that as the everyday Windows path if the chainload never settles.
- **After a Windows feature update.** A major Windows update can rewrite the
  firmware boot order or drop the Ryoku NVRAM entry, so the machine boots
  straight into Windows. The `EFI/BOOT` fallback loader on the Ryoku ESP still
  boots the disk, so select the Ryoku disk from the firmware boot menu; to make
  it persist, re-register the entry (point `--disk` / `--part` at your Ryoku ESP):

  ```
  efibootmgr --create --disk /dev/nvme0n1 --part 4 \
    --loader '\EFI\limine\limine_x64.efi' --label 'Ryoku Linux'
  ```
- **No in-place Windows reinstalls or upgrades on this layout.** Microsoft does
  not officially support two ESPs on one disk; a Windows setup or in-place upgrade
  can write to the wrong ESP or reshuffle boot entries. If you must reinstall
  Windows, use clean Windows media and expect to re-register the Ryoku boot entry
  (above) afterward.

## Broadcom Wi-Fi

**Symptom.** No Wi-Fi on a machine with a Broadcom BCM43xx card, in the live
environment or after install.

**Cause.** The in-kernel `b43`/`brcmsmac` drivers often cannot associate; these
cards need the out-of-tree `broadcom-wl` driver.

**What the installer does.** The live ISO ships `broadcom-wl`, and the backend
adds `broadcom-wl` to the `pacstrap` set for the target when a Broadcom PCI device
(vendor `14e4:`) is present.

**What the user must do.** Usually nothing. If a card still will not associate,
check `rfkill` (a hardware switch or soft block) and the wireless regulatory
domain.

## RTC clock skew vs pacman signatures

**Symptom.** The install fails with TLS "certificate is not yet valid" / "expired"
errors, or pacman signature-verification failures. Common on a laptop with a dead
CMOS battery.

**Cause.** A wildly wrong system clock makes TLS reject every certificate and
breaks pacman's signature checks.

**What the installer does.** When a mirror probe fails, `network.sh`
(`ryoku_fix_clock_skew`) reads the mirror's own clock over an unverified
connection (so the skewed cert cannot block it) and, if the system clock is off
by more than a day, sets it from the HTTP `Date` header and re-probes once. This
is best-effort and never aborts the install on its own; the live ISO also runs
`systemd-timesyncd`.

**What the user must do.** If it still fails (no network to read a `Date` header
from), set the correct date and time in firmware setup, or run
`timedatectl set-time` on the live shell, then retry. Replace the CMOS battery to
make the fix stick across power-off.

## NVRAM-readonly firmware

**Symptom.** The install completes but the machine boots straight into Windows or
the firmware boot menu; the Ryoku entry never appears or does not persist.

**Cause.** Some firmware ignores or will not persist `efibootmgr` NVRAM writes.

**What the installer does.** `bootloader.sh` writes the Limine binary to both the
tool-managed path (`EFI/limine/limine_x64.efi`) and the removable-media fallback
path (`EFI/BOOT/BOOTX64.EFI`) on the ESP, so the disk is bootable even with no
working NVRAM entry. The `efibootmgr` registration is best-effort on top of that.

**What the user must do.** In firmware setup, add a boot entry pointing at
`\EFI\limine\limine_x64.efi` on the Ryoku ESP, or move the Ryoku entry to the top
of the boot order. On firmware that only boots the removable path, the fallback
loader already covers it; just select the disk.

## Ventoy and other loop-mounted media

**Symptom.** "No space left" or squashfs failures during live boot when booted
from Ventoy.

**Cause.** Ventoy loop-mounts the ISO and injects its own boot shim, which breaks
archiso's squashfs discovery (the UUID search that finds the airootfs and the
`cow_spacesize` overlay it sets up).

**What the installer does.** Nothing can repair a Ventoy boot from inside the
image. The ISO does raise the copy-on-write overlay to 1 GiB to reduce the
"no space" class, but Ventoy is unsupported.

**What the user must do.** Write the ISO raw with `dd` (or Rufus in DD mode on
Windows) to a dedicated stick, and verify it against the `SHA256SUMS` the build
writes next to the ISO.

```
dd if=ryoku-<date>-x86_64.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

## Slow or flaky USB media

**Symptom.** The install is painfully slow, or the stick is flaky and the live
system falls over when it is jostled or pulled mid-install.

**Cause.** The live system reads the squashfs from the stick throughout the
install, so a slow or unreliable stick drags on or dies.

**What the installer does.** The ISO ships a "copy to RAM (copytoram)" boot entry
that loads the whole image into RAM before boot, so the install runs entirely
from memory and no longer depends on the stick.

**What the user must do.** Pick the **copy to RAM (copytoram)** boot entry. It is
slow to start (it reads the whole image once) but resilient afterwards, and
tolerates a removed or flaky drive. It needs enough RAM to hold the image.
