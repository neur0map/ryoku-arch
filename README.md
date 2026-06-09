<div align="center">

<img src="https://raw.githubusercontent.com/neur0map/ryoku-arch/main/assets/brand/logo-mark.png" alt="Ryoku" width="160" />

# Ryoku Arch

**力と美のために** &middot; *For the sake of power and beauty.*

Ryoku is a modular Arch distro: a polished, pre-riced base you extend with open
plugins and an extras catalogue. The base stays lean, and you scale it up with the
modules and tools you actually use, so the machine feels fast, sharp, and
deliberate from first boot.

[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-F25623?style=for-the-badge)](LICENSE)
[![Built on Arch](https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=archlinux&logoColor=white)](https://archlinux.org)
[![Hyprland](https://img.shields.io/badge/Hyprland-58E1C2?style=for-the-badge&logoColor=white)](https://hypr.land)
[![Status: 0.1.0-beta1](https://img.shields.io/badge/status-0.1.0--beta1-F25623?style=for-the-badge)](#status)
[![Build ISO](https://github.com/neur0map/ryoku-arch/actions/workflows/build-iso.yml/badge.svg)](https://github.com/neur0map/ryoku-arch/actions/workflows/build-iso.yml)
[![Latest ISO](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fiso.ryoku.dev%2Fstable%2Flatest.json&query=%24.tracking_id&label=latest%20ISO&color=F25623&style=for-the-badge)](https://ryoku.dev)
[![Discord](https://img.shields.io/badge/Discord-join-5865F2?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/8KjBmUEyKA)
[![Reddit](https://img.shields.io/badge/Reddit-r%2FRyokuArch-FF4500?style=for-the-badge&logo=reddit&logoColor=white)](https://www.reddit.com/r/RyokuArch/)

<kbd>[Vision](docs/vision.md)</kbd> &middot; <kbd>[Docs](docs/)</kbd> &middot; <kbd>[Customize](docs/customization-inventory.md)</kbd> &middot; <kbd>[Keybindings](docs/keybindings.md)</kbd> &middot; <kbd>[Discord](https://discord.gg/8KjBmUEyKA)</kbd> &middot; <kbd>[Subreddit](https://www.reddit.com/r/RyokuArch/)</kbd>

<p>
  <a href="https://youtu.be/h18vLuERKFo">
    <img src="https://img.youtube.com/vi/h18vLuERKFo/maxresdefault.jpg" alt="Ryoku showcase: watch on YouTube" width="960" />
  </a>
</p>

<sub>&#9654; <a href="https://youtu.be/h18vLuERKFo">Watch the Ryoku showcase on YouTube</a></sub>

</div>

---

## About

Ryoku is modular by design. The base install is lean enough to browse and do
everyday work on a modest machine, and grows only as you add plugins (workflow
modules) and extras (apps, tools, and the drivers and dependencies they need).
You decide how heavy your Ryoku is.

The current desktop is Hyprland with a Quickshell shell layer. The install and
core command shape descend from Omarchy, integrated into Ryoku's own
plugin-first surface. The product is coherent by design: one Ryoku system whose
surfaces are continuously refined as the workstation matures.

The goal is simple: power and beauty in the same system. Fast windowing, a
strict command surface, good defaults, strong visual identity, and a plugin and
extras model that adds real capability instead of turning the desktop into a
pile of loose tray apps.

## Position

Ryoku is a modular Arch distro: a polished base, extended by open plugins and an
extras catalogue, that scales from a light everyday setup to a fully loaded
workstation.

Ryoku is:

- **Modular Arch, not a separate kernel.** An Arch environment with its own
  defaults, install flow, shell, commands, and branding, built to be extended.
- **Pre-riced by default.** The first boot already feels intentional.
- **Plugin-first and open.** Plugins feel native to the shell and are open
  source, so anyone can read them, fork them, or write their own. VPN, capture,
  media, developer, hardware, and security workflows are plugins, not bolt-ons.
- **Extras-aware.** The extras catalogue installs apps and tools and pulls in the
  compatible drivers and dependencies they need, so adding capability does not
  mean hunting packages by hand.
- **Scales with you.** A lean base for browsing and everyday use; heavier only as
  you add the plugins and extras you want.

Ryoku is not:

- A fixed, one-size image you cannot shape.
- A minimal window-manager starter kit with no direction.
- A frozen design; Ryoku's surfaces keep evolving.

## What ships

- **Base desktop:** Hyprland Wayland session, the Quickshell-based Ryoku shell
  (launcher, sidebars, dashboard, session controls), and SDDM theming.
- **Ryoku core:** `ryoku-*` commands for updates, migrations, packages,
  snapshots, hardware helpers, themes, wallpaper, keybinds, and app launchers.
- **Plugins:** native, open-source shell and command modules for VPN, Tailscale,
  screenshots, media, developer tools, and hardware controls. Read them, fork
  them, or write your own.
- **Extras:** a catalogue that installs apps and tools plus the compatible
  drivers and dependencies they need, routed to the right backend (official
  repos, AUR) automatically.
- **Brand:** Greek Noir, the Ryoku `力` mark, and the slogan:
  **力と美のために** - *For the sake of power and beauty.*

## Status

First beta. Ryoku has cut **0.1.0-beta1**: the move from the previous setup to the
Hyprland Ryoku shell has reached beta, and the install flow runs end to
end, including verified dual-boot alongside an existing OS. Signed ISO builds are
published at [ryoku.dev](https://ryoku.dev); see [Download and verify](#download-and-verify),
or build from source. The stable release is the next milestone.

The active workstation track is Hyprland. Development happens on
`unstable-dev`, then stabilizes into `main` for release users. The shell keeps
evolving: Ryoku builds on its Omarchy install/core ancestry as the Ryoku-owned
plugin shell matures.

| Question | Answer |
|---|---|
| Minimum RAM | **8GB for the base install** (browser and everyday use). RAM scales with what you add: plugins and extras like VMs, gaming, or creative tools want 16GB+, and 32GB+ for heavy multitasking. |
| Target hardware | Modern desktops and laptops. The base runs on modest machines and scales up; NVIDIA, hybrid, AMD, and Intel graphics are all target classes. |
| Is the ISO downloadable? | Yes. `0.1.0-beta1` builds are published at [ryoku.dev](https://ryoku.dev); see [Download and verify](#download-and-verify). You can also build from source. |
| Can I build it myself? | Yes. Use the [ISO build recipe](docs/iso-build-recipe.md) if you want to build from source. |
| Are plugins and extras installed by default? | No. The base ships lean; you add plugins and extras as you need them. |
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

Layer just the Ryoku shell onto an Arch-family system you already use. The
installer is a guided `gum` interface: it tells you whether your distro is
supported (and why not, if it isn't), recommends a system snapshot, installs
every dependency and driver the shell uses, and stays reversible.

From a clone of the repo:

```bash
git clone https://github.com/neur0map/ryoku-arch.git
cd ryoku-arch
shell-install/install --dry-run   # preview the full plan, change nothing
shell-install/install             # guided install (verdict, snapshot, confirm)
shell-install/uninstall           # revert everything it did
```

Or bootstrap with one command. It pulls the live installer straight from the
repo (channel `main` by default; set `RYOKU_REF=unstable-dev` for the dev
channel), so the link never needs updating:

```bash
curl -fsSL https://shell.ryoku.dev/install.sh | bash
```

It hard-stops with the reason on anything outside the Arch family, backs up
whatever it would replace, installs GPU/firmware drivers as packages (boot
config is opt-in with `--with-boot-config`), and adds the shell as a separate
login session, so your current desktop is untouched until you pick **Ryoku** at
the login screen. See [`shell-install/README.md`](shell-install/README.md).

## Download and verify

Signed builds are published on the website at [`https://ryoku.dev`](https://ryoku.dev).
Use the Download page to get the latest ISO, signature, and checksums. The latest
ISO badge above tracks the current published build id.

Prefer to build it yourself? Use the repo-local ISO tooling:

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
