# What Ryoku is

Ryoku (力, "power") is a hand-built Arch Linux distribution: a complete,
opinionated Hyprland desktop plus the installer and system definition that
reproduce it on any machine. The whole thing lives in this one repository and is
built from it; the live machine is only ever a deployment target.

## Goals

- **A cohesive Wayland desktop.** One look, one motion language, one control
  plane. The bar, panels, launcher, lock screen, and screenshot tool are parts of
  a single shell, not a pile of unrelated widgets.
- **Reproducible.** A fresh install reaches the same desktop the repo describes,
  from one source of truth.
- **Works on day one.** Sensible defaults that are actually usable immediately:
  the developer toolchains and their package managers work without root, theming
  follows the wallpaper, hardware (GPU, displays, laptop power) is detected and
  configured automatically.
- **Minimal and legible.** No cruft, no dead code, no duplicated config. Small,
  focused files you can read.

## How the parts fit

- **The shell** (`ryoku/shell/`) is the desktop UI. `quickshell/` is the QML
  front end (the morphing `pill` bar, `sidebar`, `topbar`, `launcher`, and
  `ryoshot` screenshot tool). `ipc/ryoku-shell` is a single Go daemon that is the
  control plane: it supervises the UI components, owns the wallpaper, clipboard,
  and lock, and answers one socket. Keybinds and the UI talk to it; it decides.
- **Hyprland** (`ryoku/hyprland/`) is the compositor, configured in Lua, one
  concern per module. Its autostart brings up the shell and the hardware helpers.
- **Theming** is wallpaper-driven: `wallust` regenerates the palette from the
  current wallpaper, and the terminal and Hyprland colors follow it. Brand-fixed
  elements (the 力 logo, a few accents) stay constant.
- **The system** (`system/`) defines the boot chain, the hardware policy
  (GPU/driver/display/power helper scripts), and the package sets.
- **The installer** (`installation/`) is a Go TUI plus a shell backend that
  partitions, pacstraps the package sets, deploys the `ryoku/` payload, and sets
  up the boot chain. The ISO bakes the repo and prebuilt binaries so an install
  needs no build toolchain.

## Working on it

Read `docs/structure.md` for where things live, `docs/conventions.md` for how to
write them, `docs/ui-ux.md` for the desktop's design and motion, and
`docs/development.md` for the deploy/test/commit loop. The cardinal rules in
`AGENTS.md` override anything that contradicts them.
