# Ryoku Arch

力と美のために: For the sake of power and beauty.

An opinionated Arch Linux distribution combining desktop ricing with a cybersecurity tooling focus. Intended for people studying or working in security who also care about how their machine looks.

## Status

Pre-alpha. Not installable as a standalone distribution yet. The repository now treats Ryoku as the canonical command, config, and documentation surface. See `docs/vision.md` for the project direction and `docs/rebrand-inventory.md` for the remaining legacy and deferred rename work.

## Credit

Ryoku Arch started as a fork of [Omarchy](https://github.com/basecamp/omarchy) by DHH. Upstream attribution remains in `NOTICE`, `LICENSE`, and maintenance docs, but the active project identity, command surface, and operator workflow are Ryoku-first.

## Migrating an Existing Install

If you already have an older Omarchy-based install and want to repoint it at Ryoku, run this from your existing local clone of the install repo:

```bash
REPO_DIR="${RYOKU_PATH:-$HOME/.local/share/ryoku}"
cd "$REPO_DIR"
git diff --quiet && git diff --cached --quiet || { echo "dirty tree, commit or stash first"; exit 1; }
git remote set-url origin https://github.com/neur0map/ryoku-arch.git
git fetch origin --tags --prune
git checkout -b main --track origin/main
git branch -D master
```

After that, `ryoku-update` is the canonical updater. Legacy updater wrappers still exist during the migration backlog, but the documented interface is Ryoku.

## License

MIT. See `LICENSE` for the full text and both the Ryoku and original omarchy copyright notices. See `NOTICE` for upstream attribution.
