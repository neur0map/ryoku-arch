<div align="center">

<img src="https://raw.githubusercontent.com/neur0map/ryoku-arch/main/ryoku/assets/brand/logo-mark.png" alt="Ryoku" width="160" />

# Ryoku Arch

**力と美のために** &middot; *For the sake of power and beauty.*

Ryoku is a hand-built Arch Linux distribution: one cohesive Hyprland desktop, a
guided installer, and the system definition that reproduces them, all from a
single repository. The base is lean enough to live in from first boot and
deliberate in how it looks and moves.

[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-F25623?style=for-the-badge)](LICENSE)
[![Built on Arch](https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=archlinux&logoColor=white)](https://archlinux.org)
[![Hyprland](https://img.shields.io/badge/Hyprland-58E1C2?style=for-the-badge&logoColor=white)](https://hypr.land)
[![Status: 0.1.0 Beta 5](https://img.shields.io/badge/status-0.1.0_Beta_5-F25623?style=for-the-badge)](https://ryoku.dev)
[![Build ISO](https://github.com/neur0map/ryoku-arch/actions/workflows/build-iso.yml/badge.svg)](https://github.com/neur0map/ryoku-arch/actions/workflows/build-iso.yml)
[![Discord](https://img.shields.io/badge/Discord-join-5865F2?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/8KjBmUEyKA)
[![Reddit](https://img.shields.io/badge/Reddit-r%2FRyokuArch-FF4500?style=for-the-badge&logo=reddit&logoColor=white)](https://www.reddit.com/r/RyokuArch/)

<kbd>[Ryoku](docs/ryoku.md)</kbd> &middot; <kbd>[Docs](docs/)</kbd> &middot; <kbd>[Structure](docs/structure.md)</kbd> &middot; <kbd>[Discord](https://discord.gg/8KjBmUEyKA)</kbd> &middot; <kbd>[Subreddit](https://www.reddit.com/r/RyokuArch/)</kbd>

<p>
  <a href="https://youtu.be/h18vLuERKFo">
    <img src="https://img.youtube.com/vi/h18vLuERKFo/maxresdefault.jpg" alt="Ryoku showcase: watch on YouTube" width="960" />
  </a>
</p>

<sub>&#9654; <a href="https://youtu.be/h18vLuERKFo">Watch the Ryoku showcase on YouTube</a></sub>

</div>

---

## About

Ryoku means power, and the name is the point. The power is a modular shell built
to be extended: the desktop is composed of small, independent surfaces, and a
plugin system is on the way, so the shell grows with what you actually use
instead of bloating by default. The beauty is the shell itself, one continuous
and deliberate surface where the bar, panels, launcher, lockscreen, and session
controls move as a single thing. 力と美のために: for the sake of power and beauty.

Underneath, Ryoku is a hand-built Arch distribution rather than a config dump.
The desktop, the installer, and the system definition all live in this
repository, and every machine is built from it; the repository is the single
source of truth, and a live machine is only ever a deployment target. The
desktop is a Hyprland Wayland session authored in Lua with the Quickshell-based
Ryoku shell on top. Its install flow and command shape descend from Omarchy, and
the shell seed is adapted from the Caelestia project and reworked into Ryoku's
own surface.

## What ships

- **The desktop** under `ryoku/`: a Hyprland session authored in Lua (not a
  hand-written `hyprland.conf`), the Quickshell-based Ryoku shell, the
  lockscreen, app configs, and brand assets.
- **The system definition** under `system/`: the boot chain, hardware policy,
  and package sets that make a machine a Ryoku machine.
- **The installer** under `installation/`: a guided TUI, the backend installer,
  and the archiso profile that builds the signed ISO.
- **The update system** under `release/`: the `ryoku` control CLI, the desktop
  packages, and the signed `[ryoku]` pacman repository.

## Updating

Everything updates through one command:

```bash
ryoku update
```

It takes a snapshot, runs the package transactions (`pacman -Syu` against the
official repos and the signed `[ryoku]` repo, then `yay` for the AUR), re-lays
the desktop configs into your home, reloads the shell, and takes a paired
post-snapshot. A failed package step aborts before anything else changes.

The desktop ships from the `[ryoku]` pacman repository, signed by the release key
and trusted through the `ryoku-keyring` package, so updates are verified the same
way the rest of the system is.

Your settings survive every update. The base configs are Ryoku-owned and
refreshed in place, while your own edits live in override files that are never
shipped or touched (`hypr/user.lua`, `kitty/user.conf`, `fish/user.fish`); they
load last, so your changes win. There is no ordered migration ledger: the config
is reconciled to the shipped state on every update, and the rare stateful fix
(disk layout and the like) is an idempotent `ryoku doctor` reconciler that runs
inside `ryoku update`. If an update goes wrong, run `ryoku rollback` or pick the
previous snapshot from the Limine boot menu.

## Recovery

When an update leaves the desktop unusable and `ryoku update` cannot fix it,
there is a last-resort recovery. It pulls the latest `main`, reinstalls the base
packages, and rebuilds and redeploys the whole desktop from source, overwriting
your Ryoku configs:

```bash
ryoku recovery
```

If the `ryoku` command itself is gone, drop to a TTY (`Ctrl+Alt+F2`, then log in)
and run the same recovery straight from the repo:

```bash
curl -fsSL https://raw.githubusercontent.com/neur0map/ryoku-arch/main/bin/ryoku-recovery | bash
```

This is a true last resort. It discards local Ryoku config customizations
(`hypr/user.lua` and friends) and resets you to the latest `main`. It refuses to
run on a machine that is not Ryoku, and asks you to confirm before it changes
anything. Pass `--yes` to skip the prompt and `--no-packages` to pull and
redeploy the configs without the pacman step.

## Install

Signed ISO builds are published at [ryoku.dev](https://ryoku.dev). Download the
latest ISO, signature, and checksums there, write it to a USB stick, and boot it.
The guided installer partitions the disk (Btrfs with subvolumes), installs the
package set and the Ryoku desktop from the signed repository, sets up the Limine
boot chain, and configures snapshots.

Releases are signed with:

- **Key:** `Ryoku Releases <releases@ryoku.dev>`
- **Fingerprint:** `EB6D 3C0F 55A7 B3CA BA6B  2838 847B 274F 025D D6E3`
- **Public key in repo:** [`keys/ryoku-release-key.pub.asc`](keys/ryoku-release-key.pub.asc)

Verify the imported key's fingerprint matches before trusting it:

```bash
gpg --import keys/ryoku-release-key.pub.asc
gpg --verify ryoku-*.iso.sig ryoku-*.iso
```

Prefer to build it yourself? The archiso profile and build script live in
`installation/iso`.

## Repository layout

| Path | One job |
|---|---|
| `ryoku/` | The desktop: the Hyprland (Lua) config, the Quickshell shell, the lockscreen, app configs, brand assets. |
| `system/` | The machine definition: boot chain, hardware policy, package sets. |
| `installation/` | How a machine is built: the TUI, the backend installer, the ISO profile. |
| `release/` | Packaging: the desktop PKGBUILDs, the `[ryoku]` repo builder, the signing keyring. |
| `docs/` | The guides. Start with [`docs/ryoku.md`](docs/ryoku.md) and [`docs/structure.md`](docs/structure.md). |

## Channels

`main` is the stable channel everyone runs; it is published to the `[ryoku]`
repository and the ISO only on tagged releases. `unstable-dev` is the maintainer
preview, consumed through the dev loop and never published. A release promotes
`unstable-dev` to `main`. See [`docs/development.md`](docs/development.md) for the
deploy, test, and commit loop.

## Credits and license

Ryoku began as an Omarchy-derived Arch environment, created by David Heinemeier
Hansson and contributors. The Ryoku shell seed is adapted from the
[Caelestia shell](https://github.com/caelestia-dots/shell), and parts of the
display configuration UI are adapted from
[DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell). Full
attribution and upstream links are in [`NOTICE`](NOTICE). Ryoku is released under
the [GNU GPL v3](LICENSE).
