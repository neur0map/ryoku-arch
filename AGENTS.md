# Ryoku Arch

A hand-built Arch Linux distribution: a Hyprland desktop (the Ryoku shell), a
guided installer, and the system definition that produces both. This repository
is the single source of truth. It deploys one way, into a live system; live
machines are never the source.

New here? Read these in order, then keep them open while you work:

- `docs/ryoku.md` what Ryoku is, who it is for, and how the parts fit.
- `docs/structure.md` the repo map: where everything lives and the one job it has.
- `docs/conventions.md` how code and configuration are written here.
- `docs/ui-ux.md` the desktop's look and motion, and how to build or replicate it.
- `docs/development.md` the workflow: deploy, test, the commit gates, and research.

## Cardinal rules

These are not negotiable. Most are enforced by the git hooks in `.githooks/`.

1. **Organization is the point.** Every file and every folder has exactly one
   purpose. Before adding anything, search the repo first; if it already exists,
   reuse it. Never keep two copies of the same thing. See `docs/structure.md`.

2. **The Hyprland config is Lua.** It is authored as Lua modules under
   `ryoku/hyprland/`, one concern per file. Never hand-write a raw
   `hyprland.conf`. A standalone daemon or app that cannot read Lua keeps its own
   native config under its own directory (for example `hypridle.conf`,
   `wallust.toml`, `kitty.conf`); that is the only reason a non-Lua config exists.

3. **One concern per file.** A Lua module does one thing. A QML component is one
   component in one file. Split things out; do not pile unrelated logic together.

4. **The repo is the source of truth.** Deployment is one way: repo to
   `~/.config` (and a few system paths). Never hand-copy a live tweak back into
   the repo; change the repo and redeploy.

5. **Always pass the git hooks. Never bypass them** (`--no-verify` is forbidden).
   Commit subjects start with an area label
   `[global|installation|system|ryoku|docs|test|tooling|release]`. No em-dash, no
   authorship/attribution trailers, no filler.

6. **Do not bury code in comments.** Code and config should read on their own.
   Comment the *why* when it is not obvious, never the *what*. Delete dead code
   instead of commenting it out. A file that is mostly comments is a smell.

7. **Binaries ship prebuilt.** Go programs are compiled into the ISO image; AUR
   packages install in the post-install step. The installed target has no build
   toolchain assumptions. See `docs/development.md`.

## Top-level map

| Path | Purpose |
|---|---|
| `ryoku/` | The desktop: app configs, the Hyprland (Lua) config, the shell UI, the lockscreen, brand assets. |
| `system/` | The machine definition: boot chain, hardware policy, package sets. |
| `installation/` | How a machine is built: the TUI, the backend installer, the ISO profile. |
| `docs/` | These guides. |
| `.githooks/` | The commit/push gates every change must pass. |

Drill into each in `docs/structure.md`.
