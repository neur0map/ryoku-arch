# Ryoku Arch

力と美のために: For the sake of power and beauty.

An opinionated Arch Linux distribution combining desktop ricing with a cybersecurity tooling focus. Intended for people studying or working in security who also care about how their machine looks.

## Status

Pre-alpha. Not installable as a standalone distribution yet. The repository currently tracks a working fork of omarchy with Ryoku-specific documentation and branding. See `docs/vision.md` for the north star and `docs/rebrand-inventory.md` for the list of pending rename work.

## Credit

Ryoku Arch is built on top of [Omarchy](https://github.com/basecamp/omarchy) by DHH. The install framework, update mechanism, theme system, and configuration conventions are inherited from omarchy; Ryoku Arch layers on a security tooling focus and a distinct aesthetic identity.

## Migrating an existing omarchy install

If you already have omarchy installed at `~/.local/share/omarchy/` and want to switch the update system to Ryoku:

```bash
cd ~/.local/share/omarchy
git diff --quiet && git diff --cached --quiet || { echo "dirty tree, commit or stash first"; exit 1; }
git remote set-url origin https://github.com/neur0map/ryoku-arch.git
git fetch origin --tags --prune
git checkout -b main --track origin/main
git branch -D master
```

Subsequent `omarchy-update` runs pull from Ryoku Arch.

## License

MIT. See `LICENSE` for the full text and both the Ryoku and original omarchy copyright notices. See `NOTICE` for upstream attribution.

<!-- update-loop probe: 20260422T214957Z -->
