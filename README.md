<div align="center">

<img src="logo-mark.png" alt="Ryoku Arch logo: the kanji 力 in accent orange" width="180" />

# Ryoku Arch

**力と美のために** &middot; *For the sake of power and beauty.*

An opinionated **Arch Linux environment** for security work, built around **Hyprland**, curated tooling, and a cohesive visual system. For people who want a workstation that feels deliberate end to end.

[![License: MIT](https://img.shields.io/badge/license-MIT-F25623?style=for-the-badge)](LICENSE)
[![Built on Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=archlinux&logoColor=white)](https://archlinux.org)
[![Hyprland](https://img.shields.io/badge/Hyprland-58E1C2?style=for-the-badge&logoColor=white)](https://hyprland.org)
[![Status: pre-alpha](https://img.shields.io/badge/status-pre--alpha-F25623?style=for-the-badge)](#status)

[Vision](docs/vision.md) &middot; [Customize](docs/customization-inventory.md) &middot; [Docs](docs/)

</div>

---

## Why Ryoku

Ryoku is a focused Arch workstation environment for people doing security work who also care about a coherent desktop. It owns its command surface, config paths, and maintenance workflow, so the machine behaves like one system instead of a pile of unrelated tweaks.

- **Curated security tooling** &mdash; selected packages from BlackArch and beyond, without kitchen-sink sprawl.
- **Hyprland desktop stack** &mdash; tiled Wayland with hypridle, hyprlock, and Ryoku defaults wired together.
- **Deliberate visual language** &mdash; boot, lock, and desktop surfaces are meant to read as one system.
- **Hardware-aware** &mdash; detection helpers for ASUS ROG, Framework 16, Dell XPS OLED, Apple Silicon, hybrid GPU, and more.

## Status

**Pre-alpha. Not ready for general installation.**

The ISO installs cleanly in a fresh VM and is in tester-grade rotation on real hardware. See [`docs/vision.md`](docs/vision.md) for direction.

Browsing the repo? Start in `bin/`, `config/`, `default/`.

## Hardware

Installs offline on most modern Intel, AMD, NVIDIA, hybrid, Apple Silicon (Asahi), and Broadcom Wi-Fi systems. Apple T2 Macs and brand-new Intel Panther Lake laptops still need a network during install for now.

Full hardware matrix and driver list lives in [`docs/iso-build-recipe.md`](docs/iso-build-recipe.md).

## Documentation

- [**Vision**](docs/vision.md) &mdash; what Ryoku is, who it is for, what it is not
- [**Maintenance**](docs/maintenance.md) &mdash; release process and workflow
- [**Rebrand Inventory**](docs/rebrand-inventory.md) &mdash; migration status from legacy names
- [**Customization Inventory**](docs/customization-inventory.md) &mdash; exhaustive table of shipped text-based customization surfaces and their safe locations
- [**AGENTS.md**](AGENTS.md) &mdash; style guide, command naming, migration format
- [**Specs &amp; Plans**](docs/) &mdash; design docs for in-flight work

## Credits

Ryoku stands on the shoulders of three upstream projects. Full attribution lives in [`CREDITS.md`](CREDITS.md) and [`NOTICE`](NOTICE).

<table>
<tr>
<td width="33%" valign="top" align="center">

### [Brain_Shell](https://github.com/Brainitech/Brain_Shell)

**Venkat Saahit Kamu** (Brainitech)

Quickshell visual layer: top bar, dashboard, popups, frame. MIT, used with permission. Vendored under [`config/quickshell/ryoku/vendor/brain-shell/`](config/quickshell/ryoku/vendor/brain-shell/).

</td>
<td width="33%" valign="top" align="center">

### [Omarchy](https://github.com/basecamp/omarchy)

The original opinionated-Hyprland-Arch project that Ryoku descends from. Tooling backbone (`ryoku-*` script ecosystem, theme pipeline, install flow) inherits its shape.

</td>
<td width="33%" valign="top" align="center">

### [qylock](https://github.com/Darkkal44/qylock)

**Darkkal44**

Optional SDDM greeter and Quickshell lockscreen themes, swappable via `ryoku-install-qylock`.

</td>
</tr>
</table>

## Star history

<div align="center">

[![Stargazers over time](https://starchart.cc/neur0map/ryoku-arch.svg?variant=adaptive)](https://starchart.cc/neur0map/ryoku-arch)

</div>

## License

[MIT](LICENSE). See [`NOTICE`](NOTICE) for upstream attribution and both copyright notices.

---

<div align="center">

**Like Ryoku? Drop a &#11088; on the repo.**

*力 &mdash; built for power and beauty.*

</div>
