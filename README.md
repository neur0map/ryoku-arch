<div align="center">

<img src="assets/brand/logo-mark.png" alt="Ryoku" width="160" />

# Ryoku Arch

**力と美のために** &middot; *For the sake of power and beauty.*

Ryoku is an opinionated Arch desktop built around Niri and Quickshell. A daily-driver Linux for cybersecurity learning and personal labs.

[![License: MIT](https://img.shields.io/badge/license-MIT-F25623?style=for-the-badge)](LICENSE)
[![Built on Arch](https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=archlinux&logoColor=white)](https://archlinux.org)
[![Niri](https://img.shields.io/badge/Niri-58E1C2?style=for-the-badge&logoColor=white)](https://github.com/YaLTeR/niri)
[![Status: public preview](https://img.shields.io/badge/status-public_preview-F25623?style=for-the-badge)](#status)
[![Build ISO](https://github.com/neur0map/ryoku-arch/actions/workflows/build-iso.yml/badge.svg)](https://github.com/neur0map/ryoku-arch/actions/workflows/build-iso.yml)
[![Latest ISO](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fiso.ryoku.dev%2Fstable%2Flatest.json&query=%24.tracking_id&label=latest%20ISO&color=F25623&style=for-the-badge)](https://ryoku.dev)

<kbd>[Vision](docs/vision.md)</kbd> &middot; <kbd>[Docs](docs/)</kbd> &middot; <kbd>[Customize](docs/customization-inventory.md)</kbd> &middot; <kbd>[Keybindings](docs/keybindings.md)</kbd>

<p>
  <a href="https://www.youtube.com/watch?v=u3rzJe3d49U">
    <img src="docs/media/showcase-poster.jpg" alt="Ryoku showcase" width="960" />
  </a>
  <br/>
  <a href="https://www.youtube.com/watch?v=u3rzJe3d49U"><strong>Watch the showcase on YouTube</strong></a>
</p>

</div>

---

## About

Most security distributions assume you'll run them in a VM and switch back to your real OS to get work done. Ryoku is for the other half of cybersecurity life: studying, lab work, CTFs, courseware, and tinkering on your own equipment, all on the same machine you actually live in. Steam, Discord, your IDE, your THM lab, the OpenVPN to your home router, on one Linux that doesn't fight you.

The desktop is Niri, a scrollable-tiling Wayland compositor, with a Quickshell-based topbar, sidebars, lock screen, and settings panel. Workflow primitives that matter to security work are built into the shell instead of bolted on as separate tray icons: a sidebar tab for OpenVPN profile management, a SecPulse indicator that tracks Tailscale and OpenVPN at a glance, an in-shell polkit agent for clean privilege escalation. The boot, lock, login, and desktop surfaces share one visual language.

Ryoku descends from omarchy and inherits its install-script architecture, theme pipeline, and command shape. The Arch base, the package selection, and the security-tooling track diverge.

## Scope

Ryoku is built for **learning and personal practice**: TryHackMe, Hack The Box, OffSec courseware, CTFs, your own home lab, your own router, and any system you own or have explicit written authorization to test.

Ryoku is **not** a Kali or Parrot replacement for real engagement work. Professional pentesting and red-team operations need things a daily-driver OS deliberately doesn't give you: client-isolated environments, clean attribution, snapshot-and-revert disposability, separation between client A's data and client B's. Use a dedicated VM, or better, a dedicated engagement laptop, for that.

You are responsible for how you use what ships here. Unauthorized scanning, exploitation, or interference with systems you do not own is illegal in most jurisdictions. Don't make this project's day harder than it needs to be.

## What ships

- **Desktop**: Niri scrollable-tiling Wayland session, Quickshell topbar / sidebars / lock / launcher / settings, SDDM with switchable themes.
- **Security primitives**: in-shell OpenVPN profile manager, Tailscale + OpenVPN bar indicators, hardened defaults (UFW, encrypted home, no telemetry phoning home).
- **Daily-driver fit**: Steam, Discord, dev toolchains (mise, Docker, common languages), media stack (mpv, browsers, image / video tools).
- **Brand**: cohesive Greek-Noir palette, custom topbar layouts, Material 3 system with switchable skins (`material`, `aurora`, `angel`, `ryoku-shell`, `cards`).

## Status

Public preview. Signed alpha ISOs are downloadable; the first tagged stable release is the next milestone.

The Niri source transition has landed. Boot verification across the hardware matrix and the curated security-tooling baseline are the gating items before a tagged release. The repo is open for review in the meantime; development happens on `main`.

| Question | Answer |
|---|---|
| Is the ISO downloadable? | Yes, signed alpha builds at `https://iso.ryoku.dev/stable/`. See [Download and verify](#download-and-verify) below. |
| NVIDIA, hybrid, AMD, Apple Silicon? | All targeted. Working hardware list and driver matrix in [`docs/iso-build-recipe.md`](docs/iso-build-recipe.md). |
| Does it bundle every pentest tool? | No. A curated track is being assembled; opt-in metas planned. Out of the box you get the desktop, not the toolbox. |
| Secure Boot? | Roadmap. Not automatic yet. |
| Stability vs. rolling Arch? | Rolling. A `ryoku-stable` branch lagging behind known-good snapshots is on the roadmap. |

## Download and verify

Signed alpha builds are published at `https://iso.ryoku.dev/stable/`:

| File | URL |
|---|---|
| ISO | `https://iso.ryoku.dev/stable/ryoku-<date>-x86_64-main.iso` |
| Signature | `https://iso.ryoku.dev/stable/ryoku-<date>-x86_64-main.iso.sig` |
| SHA256 | `https://iso.ryoku.dev/stable/ryoku-<date>-x86_64-main.iso.sha256` |
| Public key | `https://iso.ryoku.dev/stable/ryoku-release-key.pub.asc` |

Releases are signed with:

- **Key:** `Ryoku Releases <releases@ryoku.dev>`
- **Fingerprint:** `621F 579B D155 94C4 DE84  0B7D 5329 7813 C0BE E055`
- **Public key in repo:** [`keys/ryoku-release-key.pub.asc`](keys/ryoku-release-key.pub.asc) (canonical, bound to git history)

Always check that the imported key's fingerprint matches the one above before trusting it; if it does not, do not import. Full verification commands are in [`docs/release-pipeline.md`](docs/release-pipeline.md).

## Browse the repo

- `bin/` shipped `ryoku-*` commands (one purpose per script).
- `config/` Niri / kitty / waybar / app configs as installed.
- `default/` theme assets, polkit rules, systemd drop-ins.
- `install/` install pipeline (`config/all.sh`, `packaging/aur-core.sh`, hardware detection).
- `shell/` the Quickshell desktop sources.

## Documentation

- [**Vision**](docs/vision.md) what Ryoku is, who it is for, what it is not.
- [**Keybindings**](docs/keybindings.md) shipped Niri and shell reference.
- [**Maintenance**](docs/maintenance.md) release process and workflow.
- [**Customization**](docs/customization-inventory.md) safe text-based customization surfaces.
- [**Branding**](docs/branding.md) visual and verbal identity.
- [**ISO build recipe**](docs/iso-build-recipe.md) end-to-end build and the working hardware matrix.
- [**Omarchy heritage**](docs/omarchy-heritage.md) what remains from upstream and why.
- [**Contributing**](CONTRIBUTING.md) focused ways to help.
- [**Security policy**](SECURITY.md) private reporting for security-sensitive issues.

## Acknowledgements

- [**iNiR**](https://github.com/snowarch/iNiR), the upstream Quickshell shell layer Ryoku ships on top of Niri.
- [**Omarchy**](https://github.com/basecamp/omarchy) by DHH, the install architecture, command shape, and theme pipeline.
- [**qylock**](https://github.com/Darkkal44/qylock) by Darkkal44, optional SDDM theme bundle.

Full attribution: [`CREDITS.md`](CREDITS.md), [`NOTICE`](NOTICE).

## License

[MIT](LICENSE).
