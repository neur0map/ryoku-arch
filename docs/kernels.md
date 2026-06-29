# Kernels

Ryoku ships and boots the stock Arch `linux` kernel. The Hub's Extras section can
add the CachyOS kernel as an opt-in alternative. This page is what to weigh
before flipping it, what it does and does not change, and how it is wired.

## Should you switch? Pros and cons

**Pros**

- An optimized, patched build: Clang ThinLTO and AutoFDO, an x86-64-v3 target,
  and the Cachy patchset.
- The mainline EEVDF scheduler with `sched-ext` compiled in, so you can opt into
  a latency or gaming scheduler (`scx_lavd` and friends) via `scx-scheds`.
- A modest, workload-dependent throughput edge on CPU-bound work, plus steadier
  behavior under load.

**Cons**

- Pulls in the CachyOS repository and signing key, so kernel updates now depend
  on one more upstream being healthy.
- Every DKMS module (NVIDIA, VirtualBox, and the like) rebuilds against the new
  kernel. A failed rebuild means that module is missing on that kernel until it
  is fixed.
- Tracks mainline more aggressively than Arch's `linux`, so marginally more
  churn.
- The gain is real for gamers and heavy multitaskers; a light desktop will barely
  notice it.

Your stock Arch kernel stays installed and remains the safe fallback you can
always boot.

## Is it still Ryoku? Is it still an opinionated install?

Yes to both.

A distribution is defined by its desktop, its tooling, its repository, and its
defaults, not by which kernel it boots. Installing `linux-cachyos` is the same
kind of choice as `linux-zen` or `linux-lts`: one swappable component. The system
stays Ryoku, on the Arch base, with the `[ryoku]` desktop, the `ryoku` CLI, and
the same opinionated defaults. `/etc/os-release` still reads exactly as before.

Opinionated does not mean fixed. The Ryoku *default* is opinionated: a fresh
install boots the stock Arch kernel, and that choice is ours to make. The CachyOS
kernel is an explicit opt-in, never the default. Opinionated by default,
swappable by choice. Offering the toggle does not dilute the default install; it
leaves it exactly as it was and hands a power user one clearly labelled lever.

## Our approach vs a full CachyOS install

These are two different things, and the difference is the whole point.

- **Ryoku plus the CachyOS kernel (this toggle).** We add only the
  `[cachyos-v3]` repository and install `linux-cachyos`. Your userland stays Arch
  plus `[ryoku]`. We do not add the CachyOS core and extra rebuilds, so a later
  `pacman -Syu` cannot quietly replace your whole userland, and we do not add the
  baseline `[cachyos]` repo that carries CachyOS's forked pacman. You keep
  Ryoku's desktop, defaults, and identity, and you borrow the kernel.
- **A full CachyOS install.** CachyOS's own ISO and installer give you their
  entire optimized userland (`cachyos-core-v3`, `cachyos-extra-v3`), their pacman
  fork, and their defaults and branding. That is a CachyOS system: a stock
  CachyOS desktop, not Ryoku's shell, Hub, or opinionated setup. The toggle
  exists so you can get the kernel's benefit without giving up the thing that
  makes the machine Ryoku.

In short: we take the one component worth borrowing and leave the rest of CachyOS
alone.

## Rollback and consequences

Rollback is built in and cheap:

- The stock Arch kernel is never removed. If the CachyOS kernel misbehaves, pick
  the stock entry at the Limine menu and you are back. There is nothing to undo.
- Installing the kernel is a pacman transaction, so snapper and snap-pac take a
  pre/post snapshot pair and limine-snapper-sync exposes them in the boot menu; a
  whole bad transaction is recoverable from the boot screen.
- To remove it outright: Extras, CachyOS Kernel, remove (or `ryoku-pkg-remove
  linux-cachyos linux-cachyos-headers`). The `[cachyos-v3]` repo line is left in
  place. It is inert with no CachyOS packages installed; delete it by hand if you
  want a clean `pacman.conf`.

Things to keep in mind: a reboot is required to actually run the new kernel; DKMS
modules rebuild on install, so watch for NVIDIA build errors; and `/boot` now
carries a second kernel image and initramfs, so it uses more space.

## How it is wired

- **Vehicle.** A `ryoku-extras` bundle (`cachyos-kernel`) with
  `requires: ["cachyos"]` and the `linux-cachyos` and `linux-cachyos-headers`
  package items. The Hub installs it through `ryoku-extras-install` like any other
  bundle.
- **Repository setup.** `ryoku-pkg-cachyos` (in `system/extras/`) adds the repo
  idempotently and additively: it recv/lsigns the CachyOS key
  (`F3B607488DB35A47`), inserts `[cachyos-v3]` above `[core]`, and runs
  `pacman -Sy`. It refuses on a CPU without x86-64-v3 and is a no-op when a
  cachyos repo is already configured.
- **Why v3 only.** `linux-cachyos` lives in `[cachyos-v3]`, which holds CachyOS's
  own packages rather than rebuilds of Arch core and extra. Adding just that repo
  means the kernel is the only thing sourced from CachyOS, so there is no
  version-skew surface against Arch and no path for `-Syu` to convert the
  userland. x86-64-v3 covers essentially every CPU since roughly 2015, and the
  kernel's v3-versus-v4 difference is negligible, so we skip v4/znver4 detection
  and the AVX-512-on-Intel-hybrid trap entirely.
- **No forked pacman.** The baseline `[cachyos]` repo (which ships CachyOS's
  patched pacman) is left out, matching CachyOS's own guidance for adding their
  repos to an Arch install.
- **Boot wiring.** On a Ryoku install, `limine-mkinitcpio-hook` regenerates the
  boot entries when the kernel package lands, so the new kernel shows up in the
  menu automatically and the stock kernel stays the default. On a box without
  that hook, add a Limine entry by hand.
- **Conflict-free, with a deploy note for maintainers.** The bundle is safe to
  re-run and never edits `[core]`/`[extra]` or the stock kernel. One ordering
  caveat: the `requires: ["cachyos"]` line needs an actuator that understands it.
  The catalogue is served from `ryoku-extras@main` to every client, while the
  actuator ships in `ryoku-desktop`. Publish the registry entry only once a
  `ryoku-desktop` release carrying the `cachyos` requires-case has shipped; an
  older actuator would otherwise mis-route `linux-cachyos` to an AUR source build.
  From that release on, the actuator aborts with a clear "run ryoku update"
  message on any requirement it does not recognize, so the case fails loudly
  instead of silently.
