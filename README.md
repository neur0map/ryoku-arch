<div align="center">

<img src="logo-mark.png" alt="Ryoku Arch logo: the kanji 力 in accent orange" width="180" />

# Ryoku Arch

**力と美のために** &middot; *For the sake of power and beauty.*

An opinionated **Arch Linux environment** for security work, built around **Hyprland**, curated tooling, and a cohesive visual system. For people who want a workstation that feels deliberate end to end.

[![License: MIT](https://img.shields.io/badge/license-MIT-F25623?style=for-the-badge)](LICENSE)
[![Built on Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=archlinux&logoColor=white)](https://archlinux.org)
[![Hyprland](https://img.shields.io/badge/Hyprland-58E1C2?style=for-the-badge&logoColor=white)](https://hyprland.org)
[![Status: pre-alpha](https://img.shields.io/badge/status-pre--alpha-F25623?style=for-the-badge)](#status)

[Vision](docs/vision.md) &middot; [Themes](#themes) &middot; [Commands](#command-surface) &middot; [Customize](docs/customization-inventory.md) &middot; [Docs](docs/)

</div>

---

## Why Ryoku

Ryoku is a focused Arch workstation environment for people doing security work who also care about a coherent desktop. It owns its command surface, config paths, and maintenance workflow, so the machine behaves like one system instead of a pile of unrelated tweaks.

- **Curated security tooling** &mdash; selected packages from BlackArch and beyond, without kitchen-sink sprawl.
- **Hyprland desktop stack** &mdash; tiled Wayland with Waybar, tofi, hypridle, hyprlock, and Ryoku defaults wired together.
- **19 first-class themes** &mdash; Catppuccin, Tokyo Night, Kanagawa, Gruvbox, Rose Pine, Everforest, and more, swappable at runtime.
- **One command surface** &mdash; primary actions live under `ryoku-*`, which makes discovery and maintenance simpler.
- **Deliberate visual language** &mdash; themes, boot surfaces, and lock surfaces are meant to read as one system.
- **Hardware-aware** &mdash; detection helpers for ASUS ROG, Framework 16, Dell XPS OLED, Apple Silicon, hybrid GPU, and more.

## Status

**Pre-alpha. Not ready for general installation.**

The ISO installs cleanly in a fresh VM and is in tester-grade rotation on real hardware. See [`docs/vision.md`](docs/vision.md) for direction.

Browsing the repo? Start in `bin/`, `config/`, `themes/`, `default/`.

## Hardware

Installs offline on most modern Intel, AMD, NVIDIA, hybrid, Apple Silicon (Asahi), and Broadcom Wi-Fi systems. Apple T2 Macs and brand-new Intel Panther Lake laptops still need a network during install for now.

Full hardware matrix and driver list lives in [`docs/iso-build-recipe.md`](docs/iso-build-recipe.md).

## Themes

Ryoku ships 19 themes out of the box. Swap any of them at runtime:

```bash
ryoku-theme-set tokyo-night
```

<table>
<tr>
<td>

**Dark**
- `catppuccin`
- `ethereal`
- `everforest`
- `gruvbox`
- `hackerman`
- `kanagawa`
- `lumon`
- `matte-black`
- `miasma`
- `nord`
- `osaka-jade`
- `retro-82`
- `ristretto`
- `rose-pine`
- `tokyo-night`
- `vantablack`

</td>
<td>

**Light**
- `catppuccin-latte`
- `flexoki-light`
- `white`

&nbsp;

**Lockscreen &amp; SDDM**

Fresh installs ship with the bundled `pixel-rainyroom` SDDM greeter so
the ISO works fully offline. Optional extra greeter and lockscreen
themes are available via [qylock](https://github.com/Darkkal44/qylock)
by Darkkal44. Install or swap extras with:

```bash
ryoku-install-qylock
```

</td>
</tr>
</table>

Themes are defined under `themes/<name>/colors.toml` with templated configs under `default/themed/*.tpl`. Add your own by copying an existing theme.

## Command Surface

Everything in Ryoku is a `ryoku-*` command. The prefix after `ryoku-` encodes intent, so discovery is just tab-completion:

| Prefix       | Purpose                                   | Example                                      |
| ------------ | ----------------------------------------- | -------------------------------------------- |
| `cmd-`       | utilities and command checks              | `ryoku-cmd-screenshot`                       |
| `pkg-`       | package management (pacman &amp; AUR)     | `ryoku-pkg-add docker`                       |
| `hw-`        | hardware detection (exit-code friendly)   | `ryoku-hw-asus-rog`                          |
| `refresh-`   | copy default config into `~/.config`      | `ryoku-refresh-config hypr/hyprlock.conf`    |
| `restart-`   | restart a desktop component               | `ryoku-restart-waybar`                       |
| `launch-`    | open applications                         | `ryoku-launch-editor`                        |
| `install-`   | install optional software                 | `ryoku-install-steam`                        |
| `setup-`     | interactive setup wizards                 | `ryoku-setup-user`                           |
| `toggle-`    | flip features on or off                   | `ryoku-toggle-nightlight`                    |
| `theme-`     | theme management                          | `ryoku-theme-set tokyo-night`                |
| `update-`    | update components                         | `ryoku-update`                               |

See [`AGENTS.md`](AGENTS.md) for conventions and how to add new commands.

## Project Layout

```text
ryoku-arch/
├── bin/              # ryoku-* commands (230+)
├── config/           # default user configs copied to ~/.config
├── default/themed/   # templated configs ({{ variable }} theme tokens)
├── themes/           # 19 theme definitions (colors.toml)
├── install/          # install phases: preflight, packaging, config, post-install
├── migrations/       # one-shot upgrade scripts (timestamp-named)
├── applications/     # .desktop files shipped with Ryoku
├── lib/              # shared bash helpers
├── docs/             # vision, specs, plans, maintenance
└── boot.sh           # online bootstrap
```

## Documentation

- [**Vision**](docs/vision.md) &mdash; what Ryoku is, who it is for, what it is not
- [**Maintenance**](docs/maintenance.md) &mdash; release process and workflow
- [**Rebrand Inventory**](docs/rebrand-inventory.md) &mdash; migration status from legacy names
- [**Customization Inventory**](docs/customization-inventory.md) &mdash; exhaustive table of shipped text-based customization surfaces and their safe locations
- [**AGENTS.md**](AGENTS.md) &mdash; style guide, command naming, migration format
- [**Specs &amp; Plans**](docs/) &mdash; design docs for in-flight work

## Credits

Ryoku builds on work that began in [**Omarchy**](https://github.com/basecamp/omarchy). Upstream attribution remains in [`NOTICE`](NOTICE) and [`LICENSE`](LICENSE); the maintained project surface here is Ryoku (`ryoku-*`, `~/.config/ryoku`, `~/.local/share/ryoku`).

The Quickshell visual layer (top bar, dashboard, popups, frame) is derived from [**Brain_Shell**](https://github.com/Brainitech/Brain_Shell) by **Venkat Saahit Kamu (Brainitech)**, MIT licensed and used with explicit permission. Vendored under `config/quickshell/ryoku/vendor/brain-shell/`; modifications are recorded in that directory's `UPSTREAM.md`. See [`CREDITS.md`](CREDITS.md) for full attribution.

SDDM greeter and Quickshell lockscreen themes ship via [**qylock**](https://github.com/Darkkal44/qylock) by Darkkal44.

## License

[MIT](LICENSE). See [`NOTICE`](NOTICE) for upstream attribution and both copyright notices.

---

<div align="center">

**Like Ryoku? Drop a &#11088; on the repo.**

*力 &mdash; built for power and beauty.*

</div>
