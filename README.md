<div align="center">

<img src="logo-mark.png" alt="Ryoku Arch logo: the kanji 力 in accent orange" width="180" />

# Ryoku Arch

**力と美のために** &middot; *For the sake of power and beauty.*

An opinionated **Arch Linux environment** for security work, built around **Hyprland**, a custom Quickshell layer, and a cohesive visual system. For people who want a workstation that feels deliberate from boot to desktop.

[![License: MIT](https://img.shields.io/badge/license-MIT-F25623?style=for-the-badge)](LICENSE)
[![Built on Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=archlinux&logoColor=white)](https://archlinux.org)
[![Hyprland](https://img.shields.io/badge/Hyprland-58E1C2?style=for-the-badge&logoColor=white)](https://hyprland.org)
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
- **Hyprland + Quickshell desktop** - tiled Wayland, Ryoku shell surfaces, hypridle, hyprlock, and Ryoku defaults wired together.
- **Deliberate visual language** - boot, lock, login, shell, and desktop surfaces are meant to read as one system.
- **Hardware-aware install path** - detection helpers for ASUS ROG, Framework 16, Dell XPS OLED, Apple Silicon, hybrid GPU, and more.

## Status

**Public preview. Signed ISO release is still pending.**

The ISO installs cleanly in a fresh VM and is in tester-grade rotation on real hardware. The repo is open for review while the first signed release, public media, and security-tooling baseline are finished.

Browsing the repo? Start in `bin/`, `config/`, `default/`.

## Hardware

Installs offline on most modern Intel, AMD, NVIDIA, hybrid, Apple Silicon (Asahi), and Broadcom Wi-Fi systems. Apple T2 Macs and brand-new Intel Panther Lake laptops still need a network during install for now.

Full hardware matrix and driver list lives in [`docs/iso-build-recipe.md`](docs/iso-build-recipe.md).

## Documentation

- [**Vision**](docs/vision.md) - what Ryoku is, who it is for, what it is not
- [**Roadmap**](docs/TODO.md) - release-readiness and polish priorities
- [**Maintenance**](docs/maintenance.md) - release process and workflow
- [**Customization Inventory**](docs/customization-inventory.md) - shipped text-based customization surfaces and their safe locations
- [**Contributing**](CONTRIBUTING.md) - focused ways to help while Ryoku is early
- [**Security Policy**](SECURITY.md) - private reporting for security-sensitive issues
- [**AGENTS.md**](AGENTS.md) - style guide, command naming, migration format

## Credits

Ryoku stands on the shoulders of upstream projects and visual references. Full attribution lives in [`CREDITS.md`](CREDITS.md) and [`NOTICE`](NOTICE).

Ryoku's centered settings panel UI is adapted from Noctalia Shell, MIT licensed, with Ryoku-specific backend adapters. See `config/quickshell/ryoku/vendor/noctalia-shell/UPSTREAM.md`.

- [**Brain_Shell**](https://github.com/Brainitech/Brain_Shell): Quickshell visual layer by **Venkat Saahit Kamu** (Brainitech): top bar, dashboard, popups, frame. MIT, used with permission. Vendored under [`config/quickshell/ryoku/vendor/brain-shell/`](config/quickshell/ryoku/vendor/brain-shell/).
- [**Omarchy**](https://github.com/basecamp/omarchy): the original opinionated-Hyprland-Arch project that Ryoku descends from. Ryoku's command ecosystem, theme pipeline, and install flow inherit its shape.
- [**qylock**](https://github.com/Darkkal44/qylock): optional SDDM greeter and Quickshell lockscreen themes by **Darkkal44**, swappable via `ryoku-install-qylock`.
- [**ilyamiro/nixos-configuration**](https://github.com/ilyamiro/nixos-configuration): dashboard audio equalizer and music-popup interaction inspiration, especially the music popup and equalizer work. Ryoku's player is a separate implementation tailored to its own dashboard, Cava, and EasyEffects wiring.

## License

[MIT](LICENSE). See [`NOTICE`](NOTICE) for upstream attribution and both copyright notices.
