# Development

The loop, the gates, and how to add things without breaking the rules.

## The loop

Edit the repo, deploy, test on the running system.

- **Shell (QML + daemon):** `ryoku/shell/dev-run.sh` builds `ryoku-shell` and
  runs it from the checkout (`qs -p`, hot-reload). `dev-binds.sh on` binds the
  shell keys for the session; `dev-stop.sh` stops it. Your own `~/.config` is not
  touched.
- **Configs:** `ryoku/shell/deploy.sh` lays the repo into `~/.config` one way, or
  let the installer's `deploy` step do it. Never edit `~/.config` and copy back.

## Verify before committing

- Lua: `luac -p <file>` parses every changed Lua file.
- Shell scripts: `bash -n <file>`; the pre-commit hook also checks staged scripts.
- Installer: run the backend with `RYOKU_DRYRUN=1` (and the required `RYOKU_*`
  vars) to print every action without touching a disk.
- QML: `qmllint` when available.
- Test behavior, not just that it parses. Exercise the actual change on the
  running system.

## Adding things

- **A package:** the right set in `system/packages/` (`base` for everyone,
  `dev` for toolchains, `hardware` per profile, `aur` for the AUR). Prefer the
  official repos over the AUR when both have it.
- **A keybind:** `ryoku/hyprland/modules/binds.lua`.
- **A Hyprland concern:** a new module under `ryoku/hyprland/modules/` plus one
  `require` in `hyprland.lua`. Do not grow an unrelated module.
- **A shell surface:** a new component under `ryoku/shell/quickshell/`, with any
  state wired through `ryoku-shell` (`ryoku/shell/ipc/`).
- **A system helper:** a `ryoku-<thing>` script under `system/hardware/.../`,
  installed via `install_bin` in `installation/backend/lib/deploy.sh`, and invoked
  by name from Lua autostart or a keybind.

## Binaries and package managers

- Go programs (the TUI, `ryoku-shell`) ship **prebuilt**: `installation/iso/
  build.sh` compiles them into the image. The target has no build toolchain;
  never assume `go` at install time.
- AUR packages install in the post-install step (`installation/backend/lib/
  aur.sh`), not via pacstrap.
- User-level package managers install without root, into `~/.local/bin` (`npm`,
  `pip --user`, `go install`, `cargo install`, `pipx`, `mise`). Do not
  reintroduce root-global installs or assume `sudo`.

## Commit gates

Every commit passes the hooks in `.githooks/`; never use `--no-verify`.

- `commit-msg`: subject is `[area] scope: summary` with area in
  `global | installation | system | ryoku | docs | test | tooling | release`
  (shell uses `[global]`). No em-dash, no authorship/attribution trailer.
- `pre-commit`: no em-dash in text files, valid bash syntax on staged scripts,
  no filler comment lines.
- `pre-push`: shellcheck when installed.

One logical change per commit. Update the matching `CHANGELOG.md` in the area you
touched, and keep the change documented where future readers will look.

## Research

When something is unfamiliar, look it up against primary sources (the Arch Wiki,
the Hyprland wiki, Quickshell and Qt docs, each tool's own docs), cross-check
anything load-bearing, and confirm the result on the running system. Match
existing patterns in the repo over introducing a new one.
