# Ryoku Arch: Vision

## Name

Ryoku (力) means "power" or "strength" in Japanese. Ryoku Arch combines that word with its Arch Linux base to signal the project's two anchors: strength in the form of security-focused tooling, and a considered aesthetic.

## Tagline

力と美のために: For the sake of power and beauty.

## What it is

An opinionated Arch Linux environment that layers a security-workstation direction on top of a ricing-focused desktop. Ryoku owns its command surface, config paths, documentation, and maintenance workflow.

## Who it is for

People studying or working in cybersecurity who also care about how their machine looks and feels.

## What distinguishes it

- A curated security-tooling track, opinionated about which tools belong in the default install and which should stay optional.
- A Hyprland + Quickshell desktop stack with Ryoku-specific defaults and branding.
- A visual system that treats boot, login, lock, shell, and desktop surfaces as one product.

## What it is not

- A general-purpose desktop distribution.
- A fork of BlackArch. Ryoku Arch layers security tooling into its own desktop opinion rather than starting from a security-first distribution and bolting ricing on afterward.
- A re-skinned Omarchy. Upstream history matters, but Ryoku now treats `ryoku-*`, `~/.config/ryoku`, and `~/.local/share/ryoku` as the canonical surfaces.

## Roadmap

Near-term priorities:

1. Ship the signed ISO pipeline and public download path.
2. Finish the first public visual showcase: screenshots, short video, and README media.
3. Lock the security-tooling baseline and separate optional personal/dev extras from default install.
4. Continue polishing the Quickshell shell surfaces, especially settings, recording, notifications, and system status.
5. Expand real-hardware install coverage before calling the ISO stable.
