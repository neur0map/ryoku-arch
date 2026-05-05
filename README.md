<div align="center">

<img src="logo-mark.png" alt="Ryoku Arch logo: the kanji 力 in accent orange" width="180" />

# Ryoku Arch

**力と美のために** &middot; *For the sake of power and beauty.*

An opinionated **Arch Linux environment** for security work, built around **Niri**, the Ryoku, and a cohesive visual system. For people who want a workstation that feels deliberate from boot to desktop.

[![License: MIT](https://img.shields.io/badge/license-MIT-F25623?style=for-the-badge)](LICENSE)
[![Built on Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=archlinux&logoColor=white)](https://archlinux.org)
[![Niri](https://img.shields.io/badge/Niri-58E1C2?style=for-the-badge&logoColor=white)](https://github.com/YaLTeR/niri)
[![Status: public preview](https://img.shields.io/badge/status-public_preview-F25623?style=for-the-badge)](#status)

[Vision](docs/vision.md) &middot; [Roadmap](docs/TODO.md) &middot; [Customize](docs/customization-inventory.md) &middot; [Docs](docs/)

<p>
  <a href="docs/media/showcase.mp4">
    <img src="docs/media/showcase-poster.jpg" alt="Ryoku Arch showcase video preview" width="960" />
  </a>
</p>

<p>
  <a href="docs/media/showcase.mp4"><strong>Watch the showcase</strong></a>
</p>

</div>

---

## Why Ryoku

Ryoku is a focused Arch workstation environment for people doing security work who also care about a coherent desktop. It owns its command surface, config paths, theme pipeline, and maintenance workflow, so the machine behaves like one system instead of a pile of unrelated tweaks.

- **Security-workstation direction** - a curated tooling track is being assembled without the kitchen-sink sprawl of a full security archive.
- **Niri + Ryoku desktop** - a scrolling-tiler Wayland session with shell overlays, launcher, lock, settings, media controls, and Ryoku defaults wired together.
- **Deliberate visual language** - boot, lock, login, shell, and desktop surfaces are meant to read as one system.
- **Hardware-aware install path** - detection helpers for ASUS ROG, Framework 16, Dell XPS OLED, Apple Silicon, hybrid GPU, and more.

## Status

**Public preview. Signed ISO release is still pending.**

The Niri source transition has landed, but the next ISO build and boot verification pass is still pending. The repo is open for review while the first signed release, current public media, and security-tooling baseline are finished.

Browsing the repo? Start in `bin/`, `config/`, `default/`.

## Hardware

Installs offline on most modern Intel, AMD, NVIDIA, hybrid, Apple Silicon (Asahi), and Broadcom Wi-Fi systems. Apple T2 Macs and brand-new Intel Panther Lake laptops still need a network during install for now.

Full hardware matrix and driver list lives in [`docs/iso-build-recipe.md`](docs/iso-build-recipe.md).

## Documentation

- [**Vision**](docs/vision.md) - what Ryoku is, who it is for, what it is not
- [**Roadmap**](docs/TODO.md) - release-readiness and polish priorities
- [**Keybindings**](docs/keybindings.md) - shipped Niri and shell keyboard reference
- [**Maintenance**](docs/maintenance.md) - release process and workflow
- [**Customization Inventory**](docs/customization-inventory.md) - shipped text-based customization surfaces and their safe locations
- [**Omarchy Heritage**](docs/omarchy-heritage.md) - what remains from upstream Omarchy and why
- [**Contributing**](CONTRIBUTING.md) - focused ways to help while Ryoku is early
- [**Security Policy**](SECURITY.md) - private reporting for security-sensitive issues
- [**AGENTS.md**](AGENTS.md) - style guide, command naming, migration format

## Credits

Ryoku stands on the shoulders of upstream projects and visual references. Full attribution lives in [`CREDITS.md`](CREDITS.md) and [`NOTICE`](NOTICE).

- [**iNiR**](https://github.com/snowarch/iNiR): the current shell layer and session UI Ryoku installs on top of Niri.
- [**Omarchy**](https://github.com/basecamp/omarchy): the original opinionated Arch project that Ryoku descends from. Ryoku's command ecosystem, theme pipeline, and install flow inherit its shape.
- [**qylock**](https://github.com/Darkkal44/qylock): optional SDDM theme bundle by **Darkkal44**, swappable via `ryoku-install-qylock`.
- [**ilyamiro/nixos-configuration**](https://github.com/ilyamiro/nixos-configuration): earlier shell audio and music-popup interaction inspiration. Ryoku does not vendor source from this repository in the current Niri tree.

## License

[MIT](LICENSE). See [`NOTICE`](NOTICE) for upstream attribution and both copyright notices.
