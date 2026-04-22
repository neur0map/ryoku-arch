# Ryoku Arch: Vision

## Name

Ryoku (力) means "power" or "strength" in Japanese. Ryoku Arch combines that word with its Linux distribution base to signal the project's two anchors: strength in the form of security tooling, and a considered aesthetic.

## Tagline

力と美のために: For the sake of power and beauty.

## What it is

An opinionated Arch Linux distribution that layers a curated cybersecurity toolset on top of a ricing-focused desktop. Built from omarchy as a starting point so the install framework, theme system, and update mechanism come pre-built.

## Who it is for

People studying or working in cybersecurity who also care about how their machine looks and feels.

## What distinguishes it

- A curated set of security tools (from the BlackArch repository and beyond), opinionated about which are included by default.
- A ricing baseline inherited from omarchy (Hyprland, Waybar, keybindings, themes) with Ryoku-specific defaults layered on top.
- A Japanese minimalism aesthetic for branding and theme work.

## What it is not

- A general-purpose desktop distribution.
- A fork of BlackArch. Ryoku Arch starts from omarchy and pulls security tooling in, rather than starting from a security-focused distribution and adding ricing.
- A drop-in replacement for omarchy. Paths, command names, and install flow match omarchy's during the bootstrap phase; they will diverge over time.

## Roadmap

This document is load-bearing across multiple specs. The initial scaffolding spec (`docs/specs/2026-04-22-ryoku-arch-scaffolding-design.md`) only sets up the repo and the dev loop. Follow-on specs cover, in rough priority order:

1. Command and path rename: `omarchy-*` to `ryoku-*`.
2. Installer migration: `boot.sh` defaults, pacman mirror configuration.
3. Security tooling curation and integration.
4. Brand assets: logo, icons, boot splash, theme defaults.
5. Japanese localization review.
