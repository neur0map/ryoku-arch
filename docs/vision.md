# Ryoku Arch: Vision

## Name

Ryoku (力) means "power" or "strength" in Japanese. Ryoku Arch uses that name
plainly: the project is about power, and about making that power beautiful.

## Tagline

力と美のために: For the sake of power and beauty.

Keep this line. It is the heart of the project.

## What it is

Ryoku is a premium Arch workstation environment for powerful desktops and
laptops. It ships a pre-riced Hyprland desktop, a Ryoku command layer, an
installer, a theme system, and a shell direction built around plugins and
first-class workflow surfaces.

Ryoku is not trying to be the smallest possible Arch setup. It assumes capable
hardware and uses that headroom for polish, visual detail, integration, and
workstation behavior.

## Who it is for

Ryoku is for users who want Arch to feel finished on strong hardware:

- desktop and laptop users who care about speed and visual identity;
- developers who want terminals, browsers, files, notes, containers, and media
  tools ready without building the whole desktop from scratch;
- power users who like a riced desktop but want the rice to be maintained as a
  product, not a private dotfiles pile;
- users who want advanced workflows exposed as plugins instead of random tray
  icons and one-off scripts.

## Intended use

The main use case is a personal workstation. Gaming, development, browsing,
media, notes, terminals, VMs, hardware controls, shell modules, and workflow
plugins should all fit into one coherent system.

Security-minded features still matter, but they are a plugin lane among others.
OpenVPN, Tailscale, hardening defaults, and enterprise tooling are optional
workflow bundles that should be easy to enable when relevant, without turning
Ryoku into a narrow security-focused profile.

For professional security-sensitive work, use a dedicated engagement
environment with client separation, snapshots, and clear operating boundaries.
Ryoku supports security-aware workflows as optional bundles, but it is a
workstation system first.

## What distinguishes it

- A premium, visual Arch workstation target: 16GB minimum, 32GB+ preferred for
  the kind of machine Ryoku wants to live on.
- A pre-riced Hyprland desktop where the default look is a product choice, not
  a placeholder.
- A plugin-first shell direction: controls for VPN, screenshots, hardware,
  updates, media, developer tools, and future workflows should become Ryoku
  plugins with matching shell surfaces.
- A strict Ryoku command and config surface: `ryoku-*` commands,
  `~/.config/ryoku`, `~/.config/ryoku-shell`, and `~/.local/share/ryoku`.
- A visual system that treats boot, login, lock, shell, terminal, and app
  defaults as one thing.

## What it is not

- A budget-PC profile.
- A minimal Arch starter kit.
- A general-purpose distro with a Ryoku wallpaper.
- A specialist engagement-focused stack.
- A final re-skin of an upstream shell. Upstream projects are important sources,
  but Ryoku's job is to turn the useful pieces into a Ryoku-owned workstation.

## Roadmap

Near-term priorities:

1. Keep the Hyprland workstation stable enough for daily use on real hardware.
2. Shape the current Quickshell-based shell into a Ryoku-owned plugin shell.
3. Keep the ISO signed, downloadable, and verifiable.
4. Move security-adjacent, developer, media, hardware, and capture workflows into clean
   plugin lanes.
5. Expand real-hardware install coverage before calling the ISO stable.
