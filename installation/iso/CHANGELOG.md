# Changelog

## Unreleased

### Fixed
- The live environment gets a 1 GiB copy-on-write overlay (`cow_spacesize=1G`
  on both boot entries) instead of archiso's 256 MiB default. A long install
  session writes sync databases, keyring state, and logs into that overlay,
  and running it dry mid-install surfaces as random "no space left" failures,
  reported from a Ventoy boot.

### Added
- Reproducible ISO builds: `build.sh` derives `SOURCE_DATE_EPOCH` from the
  commit's committer date and exports it to `mkarchiso` and `profiledef.sh`; the
  three prebuilt Go binaries build with `-trimpath -ldflags '-s -w -buildid='`
  and `CGO_ENABLED=0` under a pinned `toolchain`; and the build emits
  `SHA256SUMS` next to the ISO. `RYOKU_ISO_REPRO=1` additionally pins
  `[core]`/`[extra]` to the commit-dated Arch Linux Archive to freeze the baked
  package set. See README, "Reproducibility".
- Payload provenance stamp: `build.sh` writes `/usr/share/ryoku/.payload`
  (commit, commit date, `VERSION`) and fills the same values into `/etc/motd`, so
  the target's deploy step can warn on ISO-vs-`[ryoku]`-repo version skew.
- Two boot fallbacks on both firmware paths (UEFI + BIOS): "safe graphics"
  (`nomodeset`) for machines that boot to a black or garbled screen, and "copy
  to RAM" (`copytoram`) for flaky or removable USB media. The normal installer
  entry stays the default.
- Live ISO packages: `pciutils` (`lspci` GPU/Wi-Fi/VMD probing), `broadcom-wl`
  (Broadcom BCM43xx Wi-Fi has no in-kernel driver), and `mdadm` + `lvm2` (so
  free-space probing reads disks with existing RAID/LVM correctly).
- Add the Ryoku live ISO profile (archiso, releng-based).
  - `profiledef.sh`: iso_name `ryoku`, label `RYOKU_<YYYYMM>`, date-stamped
    version, `install_dir=arch`, BIOS (syslinux) and UEFI (systemd-boot) boot
    modes, x86_64, zstd squashfs, and file permissions for the launchers.
  - `packages.x86_64`: the live environment only. Base system, kernel, archiso
    hooks, both bootloaders, the backend toolchain, NetworkManager + iwd, and
    cage + foot + the JetBrains Mono Nerd Font. No Go: the TUI ships prebuilt.
  - airootfs overlay: root autologin on tty1, a tty1-only login path
    (`.bash_profile` -> `.zlogin`), and `ryoku-installer-session`, which runs the
    TUI in cage + foot with a crash-relaunch loop and exports `RYOKU_REPO` and
    `RYOKU_BACKEND`. NetworkManager is enabled with iwd as its Wi-Fi backend so
    the TUI's `nmcli` calls work. The serial console stays a plain root shell.
  - `build.sh`: stages a throwaway copy of the profile, builds the TUI from
    `../tui`, bakes the TUI, the backend (under `/usr/local/lib/ryoku/backend`
    with a `/usr/local/bin/ryoku-install` wrapper), and the repo payload (at
    `/usr/share/ryoku`, tracked files only via `git archive`) into the staged
    airootfs, then runs `mkarchiso`. The committed profile is never mutated.
  - `build.sh` also prebuilds the `ryoku-shell` daemon (Go) from `ryoku/shell/ipc`
    into the repo payload, so the backend can install it on the target, which has
    no Go toolchain.

### Fixed
- Drop the inline comments from `packages.x86_64`: mkarchiso left their trailing
  whitespace on the package names, so pacstrap reported "target not found".
- Suppress `systemd-firstboot`: ship `/etc/locale.conf`, `hostname`, `localtime`,
  and `vconsole.conf` and mask the service, so the image autostarts the installer
  instead of the stock Arch "Initial Setup" prompt.
- Ship a working `/etc/pacman.d/mirrorlist`: the Fastly CDN mirror
  (`fastly.mirror.pkgbuild.com`) leads, then the routed `geo.mirror.pkgbuild.com`
  and global backups. The default all-commented list left pacstrap with no
  servers; Fastly's edge POPs (incl. South America) keep downloads fast where the
  geo mirror has no nearby origin (it otherwise routes Brazil to Los Angeles).
- Ship `reflector` in the live set so the backend re-ranks the package mirrors by
  measured speed before pacstrap (see the backend's `lib/mirrors.sh`). The static
  Fastly-led list still stalled for users its CDN routes badly; ranking at install
  time picks a nearby fast mirror and falls back to the shipped list.
- Initialize the live pacman keyring: ship and enable `pacman-init.service` plus
  the gnupg tmpfs mount (as releng does), so pacstrap can verify packages.
- Force a truecolor TUI and quiet the boot: the session exports
  `COLORTERM=truecolor`, and the kernel cmdline gains `quiet loglevel=3` to hide
  amdgpu link-training console spam before the installer.
- Add `xorg-xwayland` to the live image so cage can start its Xwayland server
  (removes the "cannot create xwayland server" error).
- Send the cage session's output to `/var/log/ryoku-session.log` and set
  `WLR_RENDERER_ALLOW_SOFTWARE=1`, so the harmless software-render "renderer did
  not support importing dma-bufs" line stays in the log instead of on the console
  where it looked like an install error. Real session failures are still logged.
