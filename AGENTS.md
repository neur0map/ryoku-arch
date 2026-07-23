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
- `docs/updates.md` how a change reaches a running machine, and the delivery contract.

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

7. **The desktop ships as signed packages.** The Go programs and the QML plugin
   build from source into the `[ryoku]` pacman repo (`release/packages/`); the
   installer adds that repo and installs `ryoku-desktop`, and AUR packages
   install in the post-install step. The live ISO prebuilds only the installer;
   the installed target has no build toolchain assumptions. See
   `docs/development.md`.

8. **Every change must reach users.** A dev box runs the checkout; users run
   packages, and `ryoku update` delivers them through `materialize` (the config)
   and `doctor` (drift). A user-facing config must be shipped by a package or
   seeded by the installer; user edits live in the `user_edits` overlay
   (`~/.config/ryoku/user_edits`), never in shipped files, and survive updates. A
   removed or renamed `shell.json` key needs a doctor
   reconciler, and work reaches users only once `main` fast-forwards. See
   `docs/updates.md`; `ryoku-dev-verify-delivery` enforces it.

## Top-level map

| Path | Purpose |
|---|---|
| `ryoku/` | The desktop: app configs, the Hyprland (Lua) config, the shell UI, the lockscreen, brand assets. |
| `system/` | The machine definition: boot chain, hardware policy, package sets. |
| `installation/` | How a machine is built: the TUI, the backend installer, the ISO profile. |
| `release/` | Packaging: the desktop PKGBUILDs, the `[ryoku]` repo, the signing keyring. |
| `docs/` | These guides. |
| `.githooks/` | The commit/push gates every change must pass. |

Drill into each in `docs/structure.md`.

<!-- prowl-agent -->
## Prowl Agent (code intelligence)

This project is indexed by **prowl-agent**. Query the index from your shell
instead of grepping and reading whole files. Answers are cited (file:line),
ranked, and token-lean (TOON format, ~40% smaller than JSON, and read more
accurately by models). The index refreshes itself on each call, so there is
nothing to start and nothing goes stale.

**Prefer a prowl-agent query before reading files manually.** Open a raw file
only after a query points you to the exact lines.

### Commands

    prowl-agent overview            # project map: docs to read, roles, entrypoints, clusters (start here)
    prowl-agent find <name>         # locate a symbol; returns its signature, file, and line range
    prowl-agent search <text>       # search content; add --smart (rerank) or --compact (files only)
    prowl-agent callers <path>      # what includes / execs / binds to a file
    prowl-agent callees <path>      # what a file includes / execs / binds to
    prowl-agent impact <path>       # blast radius: dependent count, subsystems, direct importers (--all = full list)
    prowl-agent relations <path>    # a file's symbols and include neighbors
    prowl-agent entrypoints <path>  # root files from which this file is reachable
    prowl-agent references <id>     # where a symbol is used: call sites + calling fn, or ref edges (id from 'find')
    prowl-agent clusters [name]     # subsystems (summaries); with a name, that subsystem's files
    prowl-agent hotspots            # structurally central / large files
    prowl-agent violations          # dangling refs, orphan scripts, hardcoded colors
    prowl-agent doctor              # health: cycles, duplicate keybinds, broken commands
    prowl-agent tests <path>        # test files covering a file (or, for a config, what launches it)
    prowl-agent changed             # your git changes mapped to the files they could affect

Every command accepts --json for JSON instead of TOON, and --limit N to cap
results (fewer tokens). Run from anywhere inside the project; prowl-agent finds
the index by walking up to .prowl/.

### When to use which

- New or unfamiliar project: overview for the map, then clusters <name> to pull a subsystem's files.
- After a find: the row carries the signature, line, and end_line, so read the signature for a symbol's interface and open only that line range when you need the body.
- Fuzzy / natural-language question: search "<text>" matches all terms when the exact phrase is absent; --smart reranks semantically (needs AI), --compact lists files first.
- Before changing any symbol (a function, a color, a variable): find it, then references <id> for its usages (cited call sites for code, reference edges for config); check violations.
- Before editing or deleting a file: impact <path> for what breaks, callers <path> for what invokes it.
- Adding a keybind: doctor first, to avoid duplicate-keybind clashes.
- Tracing startup: entrypoints <path> for the entry point and autostart chain.
- After editing, or before committing: changed to see what your edits could affect, then doctor.

The same index is also available over MCP (server: `prowl-agent serve`) for
agents that prefer typed tools, but the shell commands above are the
recommended, lowest-overhead path (no server, no per-call schema cost).
<!-- /prowl-agent -->
