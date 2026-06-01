<div align="center">

<img src="https://raw.githubusercontent.com/neur0map/ryoku-arch/main/assets/brand/logo-mark.png" alt="Ryoku" width="160" />

# Ryoku Arch

**力と美のために** &middot; *For the sake of power and beauty.*

Ryoku is a premium Arch workstation for powerful desktops and laptops. It is
pre-riced, plugin-minded, and built for people who want their Linux machine to
feel fast, sharp, and deliberate from first boot.

[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-F25623?style=for-the-badge)](LICENSE)
[![Built on Arch](https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=archlinux&logoColor=white)](https://archlinux.org)
[![Hyprland](https://img.shields.io/badge/Hyprland-58E1C2?style=for-the-badge&logoColor=white)](https://hypr.land)
[![Status: 0.1.0-beta1](https://img.shields.io/badge/status-0.1.0--beta1-F25623?style=for-the-badge)](#status)
[![Build ISO](https://github.com/neur0map/ryoku-arch/actions/workflows/build-iso.yml/badge.svg)](https://github.com/neur0map/ryoku-arch/actions/workflows/build-iso.yml)
[![Discord](https://img.shields.io/badge/Discord-join-5865F2?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/8KjBmUEyKA)
[![Reddit](https://img.shields.io/badge/Reddit-r%2FRyokuArch-FF4500?style=for-the-badge&logo=reddit&logoColor=white)](https://www.reddit.com/r/RyokuArch/)

<kbd>[Vision](docs/vision.md)</kbd> &middot; <kbd>[Docs](docs/)</kbd> &middot; <kbd>[Customize](docs/customization-inventory.md)</kbd> &middot; <kbd>[Keybindings](docs/keybindings.md)</kbd> &middot; <kbd>[Discord](https://discord.gg/8KjBmUEyKA)</kbd> &middot; <kbd>[Subreddit](https://www.reddit.com/r/RyokuArch/)</kbd>

<p>
  <img src="https://raw.githubusercontent.com/neur0map/ryoku-arch/main/showcase.png" alt="Ryoku showcase" width="960" />
</p>

</div>

---

## About

Ryoku is not trying to be the lightest Arch setup in the room. It takes the
other lane: a polished workstation that assumes the machine has room to breathe.
The target is a strong desktop or laptop, not a budget box that needs every
megabyte saved.

The current desktop is Hyprland with a Quickshell shell layer. The install and
core command shape still descend from Omarchy, while the active shell is being
shaped into Ryoku's own plugin-first surface. That is intentional for now: take
the useful base, make the product coherent, then replace borrowed parts as
Ryoku-owned surfaces mature.

The goal is simple: power and beauty in the same system. Fast windowing, a
strict command surface, good defaults, strong visual identity, and plugins that
add real workstation behavior instead of turning the desktop into a pile of
loose tray apps.

## Position

Omarchy is a lean, opinionated Arch install that can fit modest laptops well.
Ryoku is the opposite side of that family tree: heavier, more visual, more
integrated, and aimed at capable hardware.

Ryoku is:

- **Premium Arch, not a separate distro.** It is an Arch environment with its
  own defaults, install flow, shell, commands, and branding.
- **Pre-riced by default.** The first boot should already feel intentional.
- **Plugin-minded.** VPN, capture, media, developer, hardware, and security
  operations can become clean Ryoku plugins and shell surfaces.
- **Built for powerful desktops and laptops.** The baseline is 16GB RAM or
  better; 32GB+ is the comfortable target for VMs, gaming, creative tools, and
  heavy multitasking.

Ryoku is not:

- A budget-PC profile.
- A minimal window-manager starter kit.
- A narrow, niche-focused workflow profile.
- A promise that every borrowed upstream piece is final.

## What ships

- **Desktop:** Hyprland Wayland session, Quickshell-based shell
  surfaces, launcher, sidebars, dashboard, session controls, and SDDM theming.
- **Ryoku core:** `ryoku-*` commands for updates, migrations, packages,
  snapshots, hardware helpers, themes, wallpaper, keybinds, and app launchers.
- **Plugin lanes:** shell and command hooks for VPN, Tailscale, screenshots,
  media, developer tools, hardware controls, and future workflow modules.
- **Workstation defaults:** Kitty, Helium/Chromium, Nautilus, Yazi, Neovim,
  Obsidian, Docker tooling, media tools, gaming-ready packages, and AUR-backed
  extras.
- **Brand:** Greek Noir, the Ryoku `力` mark, and the slogan:
  **力と美のために** - *For the sake of power and beauty.*

## Status

First beta. Ryoku has cut **0.1.0-beta1**: the move from the Niri/iNiR setup to
the Hyprland/Caelestia shell has reached beta, and the install flow runs end to
end, including verified dual-boot alongside an existing OS. Public ISO downloads
stay paused until a published release build is ready; build from source in the
meantime. The stable release is the next milestone.

The active workstation track is Hyprland. Development happens on
`unstable-dev`, then stabilizes into `main` for release users. The shell is in
transition: Ryoku is using Omarchy install/core ancestry while the Ryoku-owned
plugin shell takes shape.

| Question | Answer |
|---|---|
| Minimum RAM | **16GB+ required.** Use **32GB+** if you expect VMs, gaming, browser-heavy work, or creative tools. This is not a low-resource target. |
| Target hardware | Modern desktops and stronger laptops. NVIDIA, hybrid, AMD, and Intel graphics are target classes. |
| Is the ISO downloadable? | Not yet. `0.1.0-beta1` is cut, but public ISO downloads stay paused until a published release build is ready. Build from source meanwhile. |
| Can I build it myself? | Yes. Use the [ISO build recipe](docs/iso-build-recipe.md) if you want to build from source. |
| Is every bundled plugin lane installed by default? | No. Ryoku ships core productivity lanes and extras as optional add-ons. |
| Secure Boot? | Roadmap. Not automatic yet. |
| Stability vs. rolling Arch? | Rolling Arch base. `unstable-dev` is the fast track; `main` is the release channel. |

## Install paths

Ryoku ships through two separate, clearly bounded paths:

- **Ryoku OS (ISO install)** the full Arch workstation: bootloader, filesystem,
  display manager, and system config. This is the product. Code in `install/`.
- **Ryoku Shell (experimental)** the Ryoku desktop shell layered onto an Arch
  system you already use, in user scope, reversible, coexisting with your
  current setup. Code in `shell-install/`.

See [install paths](docs/install-paths.md) for the full comparison, and
[`shell-install/README.md`](shell-install/README.md) for the experimental shell
installer.

### Install the Ryoku shell (experimental)

This works from any branch. Clone the repo and run the installer from the
checkout you are on:

```bash
git clone https://github.com/neur0map/ryoku-arch.git
cd ryoku-arch
# git checkout <branch>   # optional: any branch you want to install from
shell-install/install --dry-run   # preview the full plan, change nothing
shell-install/install             # install (runs safety checks, asks to confirm)
```

Or bootstrap with one command. Set `branch` once so the fetched script and the
cloned ref always match, so it stays correct on `main`, `unstable-dev`, or any
feature branch:

```bash
branch=main
RYOKU_REF="$branch" bash <(curl -fsSL "https://raw.githubusercontent.com/neur0map/ryoku-arch/$branch/shell-install/boot.sh")
```

It runs hard safety checks first and stops if the machine is not safe, backs up
your current setup before any change, and is reversible with
`shell-install/uninstall`.

## Build From Source

Public ISO downloads are paused for now. If you want to test Ryoku anyway, build
from source with the repo-local ISO tooling:

- [ISO build recipe](docs/iso-build-recipe.md)
- [Release pipeline notes](docs/release-pipeline.md)

Releases are signed with:

- **Key:** `Ryoku Releases <releases@ryoku.dev>`
- **Fingerprint:** `621F 579B D155 94C4 DE84  0B7D 5329 7813 C0BE E055`
- **Public key in repo:** [`keys/ryoku-release-key.pub.asc`](keys/ryoku-release-key.pub.asc)

Always check that the imported key's fingerprint matches the one above before
trusting it. Full verification commands are in
[`docs/release-pipeline.md`](docs/release-pipeline.md).

## Browse the repo

- `bin/` shipped `ryoku-*` commands, one purpose per script.
- `config/` Hyprland, terminal, app, and user config seeds.
- `default/` system defaults, templates, boot assets, and service drop-ins.
- `install/` OS/ISO installer, package manifests, hardware setup, first-run flow.
- `shell-install/` experimental shell-only installer for existing Arch systems.
- `shell/` the current Quickshell-based Ryoku shell sources.
- `themes/` Ryoku and user-selectable theme payloads.

## Documentation

- [**Vision**](docs/vision.md) product direction, audience, non-goals.
- [**Keybindings**](docs/keybindings.md) shipped Hyprland and shell reference.
- [**Plugins**](docs/plugins.mdx) current and planned workflow plugins.
- [**Maintenance**](docs/maintenance.md) release process and workflow.
- [**Customization**](docs/customization-inventory.md) safe text-based customization surfaces.
- [**Branding**](docs/branding.md) visual and verbal identity.
- [**ISO build recipe**](docs/iso-build-recipe.md) build recipe and hardware notes.
- [**Heritage**](docs/omarchy-heritage.md) upstream inheritance and compatibility boundaries.
- [**Contributing**](CONTRIBUTING.md) focused ways to help.
- [**Security policy**](SECURITY.md) private reporting for security-sensitive issues.

## Acknowledgements

- [**Omarchy**](https://github.com/basecamp/omarchy) by DHH, for the install
  architecture, command shape, and early Arch desktop foundation.
- [**ActivSpot**](https://github.com/Devvvmn/ActivSpot) by Devvvmn, for Dynamic
  Island code adapted into Ryoku's island work and launcher/island inspiration.
- [**qylock**](https://github.com/Darkkal44/qylock) by Darkkal44, optional SDDM
  theme bundle.

Full attribution: [`CREDITS.md`](CREDITS.md), [`NOTICE`](NOTICE).

## License

[GPL-3.0](LICENSE). MIT notices for inherited permissive components are
preserved under [LICENSES](LICENSES/).
