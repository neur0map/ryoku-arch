# Ryoku Live Recovery And Niri Transition Design

## Context

The live machine is a fresh Omarchy install. It is disposable: no current
Omarchy user config, state, or app customization needs to be preserved. The
goal is to restore Ryoku as the live system backend under Hyprland first, then
transition to Niri/iNiR only after Ryoku is stable again.

Observed live state on 2026-05-02:

- `OMARCHY_PATH=/home/carlos/.local/share/omarchy`
- `XDG_CURRENT_DESKTOP=Hyprland`
- `DESKTOP_SESSION=hyprland-uwsm`
- `~/.local/share/omarchy` exists.
- `~/.local/share/ryoku` does not exist.
- `~/.config/omarchy` exists.
- `~/.config/ryoku` does not exist.
- `~/.config/hypr` exists.
- `~/.config/niri` does not exist.
- `niri`, `inir`, `quickshell`, `qs`, `fuzzel`, and `tofi` are not installed.
- `/usr/share/wayland-sessions` contains only `hyprland.desktop` and
  `hyprland-uwsm.desktop`.

Relevant Ryoku repo guidance:

- `docs/rebrand-inventory.md` is the source of truth for Omarchy to Ryoku
  namespace and infrastructure independence.
- `docs/branding.md` is the source of truth for Ryoku brand assets and copy.
- `docs/maintenance.md` explains which changes belong in install scripts,
  migrations, commands, and live update flow.

iNiR references checked during design:

- https://github.com/snowarch/iNiR
- https://github.com/snowarch/iNiR/blob/main/docs/INSTALL.md
- https://github.com/snowarch/iNiR/blob/main/docs/IPC.md
- https://github.com/snowarch/iNiR/blob/main/docs/PACKAGES.md
- https://github.com/snowarch/iNiR/blob/main/ARCHITECTURE.md

## Goals

- Restore Ryoku live identity and backend on the current machine while keeping
  Hyprland as the temporary known-working session.
- Move live system ownership from Omarchy paths to Ryoku paths.
- Delete Omarchy live files after the equivalent Ryoku paths exist and are
  verified.
- Avoid preserving current Omarchy user config.
- Keep the development repo at `/home/carlos/prowl/ryoku-arch` read-only during
  live recovery and iNiR installation.
- Do not modify Ryoku source for Niri/iNiR integration until Niri and iNiR are
  confirmed working on the live system.
- Capture enough detail in docs and plans that another session can resume.

## Non-Goals

- Do not migrate current Omarchy personal config into Ryoku.
- Do not immediately replace Hyprland with Niri.
- Do not remove the Hyprland login session before Niri/iNiR is tested.
- Do not edit shell/QML/backend code to support Niri until the live Niri/iNiR
  baseline is working.
- Do not merge iNiR into the Ryoku repo as the first step.

## Phase 1: Ryoku Recovery Under Hyprland

The first milestone is a clean Ryoku takeover while still logging into
`hyprland-uwsm.desktop`.

The live checkout should become:

- `~/.local/share/ryoku` as the canonical live repo.
- `~/.config/ryoku` as the canonical config namespace.
- `~/.local/state/ryoku` as the canonical state namespace.
- `$HOME/.local/share/ryoku/bin` first on `PATH`.
- Ryoku defaults copied into `~/.config`.
- Ryoku Quickshell copied to `~/.config/quickshell/ryoku`.
- SDDM using the Ryoku greeter configuration while still offering Hyprland.

Omarchy files are removed after verification:

- `~/.local/share/omarchy`
- `~/.config/omarchy`
- `~/.local/state/omarchy`
- any remaining shell profile references that prepend
  `~/.local/share/omarchy/bin`

The migration step should use the legacy Omarchy migration markers before
deleting `~/.local/state/omarchy`. `ryoku-migrate` intentionally bridges those
markers so already-applied historical Omarchy migrations do not all re-run on
the fresh system. This is not preserving user config; it is preventing obsolete
one-shot migrations from running twice.

## Phase 2: Niri/iNiR Baseline

After Ryoku works under Hyprland, install Niri and iNiR on the live system as a
reference Niri shell without modifying Ryoku source.

iNiR's documented Arch path is:

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install
niri msg action load-config-file
```

iNiR provides its own CLI and IPC surface through commands such as:

- `inir run`
- `inir settings`
- `inir logs`
- `inir doctor`
- `inir <target> <function>`

The Niri/iNiR milestone is complete only when a real Niri session starts, iNiR
surfaces render, `inir doctor` reports a usable state, and Hyprland remains
available as fallback.

## Phase 3: Ryoku Niri/iNiR Integration

Only after Phase 2 is confirmed should the development repo be modified.

The integration direction is:

- Keep `ryoku-*` commands as the public Ryoku surface.
- Decide whether to wrap `inir` CLI targets behind `ryoku-ipc` or port iNiR
  shell pieces into Ryoku.
- Replace or abstract Hyprland-specific Ryoku backend calls, including:
  - SDDM session hard-checks.
  - Hyprland autostart config.
  - `hyprctl` dispatches in `ryoku-ipc` and restart helpers.
  - `xdg-desktop-portal-hyprland` restart assumptions.
  - Hyprland keybinding files and plain binding docs.
  - Hyprland theme templates and monitor/window helper commands.
- Preserve Ryoku branding, path namespaces, package lists, theme pipeline, and
  maintenance/update model.

## Risks

- Running every historical migration from scratch can break a fresh Omarchy
  system. The plan avoids that by letting `ryoku-migrate` bridge existing
  Omarchy markers before deleting Omarchy state.
- `ryoku-reinstall-configs` refreshes Limine and Plymouth, which touches system
  boot assets. Run it only with the live machine on power and with Hyprland
  fallback available.
- iNiR is a full shell with its own config, CLI, and service assumptions. It
  should be treated as a working reference install first, not immediately
  vendored into Ryoku.
- Deleting Omarchy paths before Ryoku commands and configs work can leave the
  session without a local recovery command surface. Deletion comes after
  verification.

## Success Criteria

Phase 1 is successful when:

- `command -v ryoku-update` resolves under `~/.local/share/ryoku/bin`.
- `~/.local/share/ryoku`, `~/.config/ryoku`, and `~/.local/state/ryoku` exist.
- `~/.local/share/omarchy`, `~/.config/omarchy`, and
  `~/.local/state/omarchy` are gone.
- `ryoku-migrate` has run without skipped migrations that block the desktop.
- `ryoku-refresh-quickshell` succeeds.
- `qs` or `quickshell` is installed.
- `ryoku-launch-shell` can start the Ryoku shell, or its failure is captured as
  the next concrete blocker.
- The user can still log into Hyprland.

Phase 2 is successful when:

- `niri` and `inir` are installed.
- A Niri wayland session exists.
- Logging into Niri reaches a usable desktop.
- `inir doctor` completes without a blocker.
- `inir run`, `inir settings`, and `inir logs` work.
- Hyprland remains available as fallback.

Phase 3 begins only after Phase 2 is confirmed.
