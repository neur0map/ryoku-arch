# Ryoku Arch: Vision

## Name

Ryoku (力) means "power" or "strength" in Japanese. Ryoku Arch combines that word with its Arch Linux base to signal the project's two anchors: strength in the form of security-focused tooling, and a considered aesthetic.

## Tagline

力と美のために: For the sake of power and beauty.

## What it is

An opinionated Arch Linux environment that layers a security-workstation direction on top of a ricing-focused desktop. Ryoku owns its command surface, config paths, documentation, and maintenance workflow.

## Who it is for

People studying or working in cybersecurity who also care about how their machine looks and feels. Students working through TryHackMe / Hack The Box / OffSec material, hobbyists building home labs, professionals who want a personal Linux that doesn't make them dual-boot to enjoy it.

## Intended use

Ryoku is a **learning and personal-practice** environment. It targets workflows where you are the authorized owner of the systems involved: your own home lab, your own router, the boxes you spun up for a course, the labs the platform exposes for you (THM, HTB, etc.).

It is deliberately **not** positioned as a Kali or Parrot replacement for real engagement work. Professional pentesting needs things Ryoku does not try to provide: client-isolated environments, clean attribution, snapshot-and-revert disposability, hard separation between client A's data and client B's, and a clear evidentiary boundary between the testing OS and the tester's personal OS. The right tool for that is still a dedicated VM or a dedicated engagement laptop.

Pitching Ryoku as something it is not would damage trust with both audiences. We are explicit on the README that this is for learning and personal labs, and that responsibility for how the tools are used lies with the user.

## What distinguishes it

- A curated security-tooling track, opinionated about which tools belong in the default install and which should stay optional.
- A Niri + Ryoku shell desktop stack with Ryoku-specific defaults and branding.
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
4. Verify the Niri ISO build and first boot path end to end.
5. Expand real-hardware install coverage before calling the ISO stable.
