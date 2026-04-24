<div align="center">

<img src="logo-mark.png" alt="Ryoku Arch logo: the kanji 力 in accent orange" width="180" />

# Ryoku Arch

**力と美のために** &middot; *For the sake of power and beauty.*

An opinionated **Hyprland desktop setup for Arch Linux**, built around a curated **cybersecurity toolkit** and a Japanese-minimalism aesthetic. For operators who study or ship security work and still care how their machine looks.

[![License: MIT](https://img.shields.io/badge/license-MIT-F25623?style=for-the-badge)](LICENSE)
[![Built on Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=archlinux&logoColor=white)](https://archlinux.org)
[![Hyprland](https://img.shields.io/badge/Hyprland-58E1C2?style=for-the-badge&logoColor=white)](https://hyprland.org)
[![Status: pre-alpha](https://img.shields.io/badge/status-pre--alpha-F25623?style=for-the-badge)](#status)

[Vision](docs/vision.md) &middot; [Install](#install) &middot; [Themes](#themes) &middot; [Commands](#command-surface) &middot; [Docs](docs/) &middot; [Upstream: Omarchy](https://github.com/basecamp/omarchy)

</div>

---

## Why Ryoku

Ryoku layers an opinionated Hyprland + Waybar + Walker desktop on top of a base Arch Linux install, then adds curated security tooling and a strong brand. It is not a distribution &mdash; it is a configuration you apply to Arch that gives you a consistent, themed, security-ready workstation.

- **Security-first toolkit** &mdash; curated picks from BlackArch and beyond, no kitchen-sink bloat.
- **Hyprland-native** &mdash; tiled Wayland with Waybar, Walker, tofi, hypridle, and hyprlock wired up.
- **19 first-class themes** &mdash; Catppuccin, Tokyo Night, Kanagawa, Gruvbox, Rose Pine, Everforest, and more, swappable at runtime.
- **One command surface** &mdash; every action is a `ryoku-*` command. Tab-complete to discover.
- **Japanese-minimalism brand** &mdash; the 力 kanji anchors a considered aesthetic across theme, boot, and lockscreen.
- **Hardware-aware** &mdash; detection helpers for ASUS ROG, Framework 16, Dell XPS OLED, Apple Silicon, hybrid GPU, and more.

## Status

**Pre-alpha.** Ryoku is not yet a one-shot installer you curl-to-shell on a fresh Arch box. The repository is the canonical source of commands, configs, and docs &mdash; see [`docs/vision.md`](docs/vision.md) for direction and [`docs/rebrand-inventory.md`](docs/rebrand-inventory.md) for the remaining cleanup.

> Running Ryoku on an existing desktop **will replace your configuration.** Use a fresh Arch install or a VM.

## Install

On a fresh Arch Linux system:

```bash
git clone https://github.com/neur0map/ryoku-arch.git ~/.local/share/ryoku
cd ~/.local/share/ryoku
./install.sh
```

After install, `ryoku-update` is the canonical updater. An `ISO`-based installer and stable `boot.sh` one-liner are on the roadmap.

### Migrating from Omarchy

If you already run an Omarchy-based install, repoint your local clone at Ryoku:

```bash
REPO_DIR="${RYOKU_PATH:-$HOME/.local/share/ryoku}"
cd "$REPO_DIR"
git diff --quiet && git diff --cached --quiet || { echo "dirty tree, commit or stash first"; exit 1; }
git remote set-url origin https://github.com/neur0map/ryoku-arch.git
git fetch origin --tags --prune
git checkout -b main --track origin/main
git branch -D master
```

From there, `ryoku-update` takes over.

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

Greeter and lockscreen themes ship via [qylock](https://github.com/Darkkal44/qylock) by Darkkal44. Install or swap with:

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
└── boot.sh           # online bootstrap (pre-alpha)
```

## Documentation

- [**Vision**](docs/vision.md) &mdash; what Ryoku is, who it is for, what it is not
- [**Maintenance**](docs/maintenance.md) &mdash; release process and workflow
- [**Rebrand Inventory**](docs/rebrand-inventory.md) &mdash; migration status from legacy names
- [**AGENTS.md**](AGENTS.md) &mdash; style guide, command naming, migration format
- [**Specs &amp; Plans**](docs/) &mdash; design docs for in-flight work

## Credits

Ryoku Arch started as a fork of [**Omarchy**](https://github.com/basecamp/omarchy) by DHH. Upstream attribution is preserved in [`NOTICE`](NOTICE) and [`LICENSE`](LICENSE); the active project surface (`ryoku-*` commands, `~/.config/ryoku`, `~/.local/share/ryoku`) is Ryoku-first.

SDDM greeter and Quickshell lockscreen themes ship via [**qylock**](https://github.com/Darkkal44/qylock) by Darkkal44.

## License

[MIT](LICENSE). See [`NOTICE`](NOTICE) for upstream attribution and both copyright notices.

---

<div align="center">

**Like Ryoku? Drop a &#11088; on the repo.**

*力 &mdash; built for power and beauty.*

</div>
