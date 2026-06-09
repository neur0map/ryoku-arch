# Ryoku Shell installer (experimental)

> **Experimental.** This installs the Ryoku *desktop shell* onto an existing
> Linux system, beside whatever you already run. It is reversible, but it is
> new and not yet widely tested. Read the plan it prints before you confirm.

This is **not** the way to install Ryoku as a full operating system. Ryoku has
two clearly separate install paths:

| | Ryoku OS (ISO install) | Ryoku Shell (this) |
|---|---|---|
| What it is | A full, opinionated Arch workstation | Just the Ryoku desktop shell, layered on |
| Where it lives | `install/`, `install.sh`, `boot.sh` | `shell-install/` |
| Target | Fresh / vanilla Arch | An Arch system you already use |
| Bootloader | Installs & manages limine | Never touched |
| Filesystem | Requires btrfs + snapper | Never touched |
| Display manager | Installs & enables SDDM | Never touched (adds a session entry) |
| Boot splash | Installs plymouth | Never touched |
| System config | Owns pacman.conf, sudoers, udev, services | User scope only |
| Reversible | No (it is the OS) | Yes (`uninstall` replays a manifest) |
| Distros | Arch only | Arch family now; extensible per adapter |

If you want the complete Ryoku experience on dedicated hardware, use the OS
install. If you already have an Arch setup you like and just want to try the
Ryoku shell, use this.

## Use

From a clone of the repo:

```bash
shell-install/install --dry-run   # show the full plan, change nothing
shell-install/install             # install (asks for confirmation, then sudo)
shell-install/uninstall           # revert everything it did
```

The installer is guided: it shows whether your distro is supported (and why, if
not), recommends a snapshot before touching anything (offering `snapper`/`timeshift`
if present), asks once to confirm, then installs. It renders with `gum` (installed
automatically) and falls back to plain text without it.

Or bootstrap directly. Set `branch` once so the fetched script and the cloned
ref match, so it works the same on any branch (`main`, `unstable-dev`, a feature
branch):

```bash
branch=main
RYOKU_REF="$branch" bash <(curl -fsSL "https://raw.githubusercontent.com/neur0map/ryoku-arch/$branch/shell-install/boot.sh") --dry-run
```

After installing, **reboot** (or fully log out), then pick the **Ryoku** session
at your login screen and log in. Your current desktop does not change until you
start the Ryoku session, so the live screen stays as-is until then.

If the desktop comes up blank (no wallpaper, keybinds, or shell), you are almost
certainly still in your old session: make sure you selected **Ryoku** at the
login screen. The installer prints a verification checklist at the end; if the
"native QML plugins (build)" line is missing, the shell could not build. Check
`~/.local/state/ryoku-shell-setup.log` and re-run.

## Safety first

Before anything is installed or changed, it runs hard safety checks and stops
if the machine is not safe to proceed on: not running as root, an Arch-family
system, `pacman` and `sudo` present, the pacman database not locked, enough
free disk for the build, and network reachable. It is universal across Arch
machines (any bootloader, filesystem, or desktop), but refuses clearly-unsafe
conditions rather than pressing on. After you consent, it takes a full backup
of your current setup before the first change.

## What it does

- Installs the full Ryoku app + dependency set from the same manifests the OS
  install uses (`install/ryoku-base.packages` + `install/ryoku-aur.packages`),
  minus the system-level packages an existing machine must not get (the display
  manager, boot splash, and bootloader/snapshot hooks). This is what makes the
  keybinds and `ryoku-*` commands actually work (terminal, file manager,
  browser, mpv, screenshot tools, and so on). Packages you already have are
  skipped (`--needed`), so your existing apps are left untouched.
- Deploys the Ryoku payload to `~/.local/share/ryoku`, builds the native QML
  plugins, and deploys the shell to `~/.config/quickshell/ryoku-shell`.
- Links `ryoku-*` commands into `~/.local/bin`.
- Seeds missing configs into `~/.config`. Your existing app configs are left
  alone; `~/.config/hypr` (which Ryoku must own for its session) is backed up
  first, then deployed.
- Adds a uniquely-named `Ryoku` wayland session beside your existing ones (the
  only thing it writes with `sudo`).
- Enables the `ryoku-shell` and `hypridle` user services.

Everything it changes is backed up under `~/.local/state/ryoku-shell/backups/`
and recorded in `~/.local/state/ryoku-shell/manifest.tsv`. `uninstall` replays
that manifest in reverse and restores your backups.

## What it never does

Touch your bootloader, kernel, initramfs, filesystem, btrfs/snapshots, display
manager, plymouth, `/etc/pacman.conf`, sudoers, or udev rules. Those belong to
the OS install only.

## Adding a distro

Support for new distros attaches here, never to the OS installer:

1. Add the distro's `/etc/os-release` `ID` to `rsi_detect_family` in
   `distros/detect.sh` (Arch derivatives already map to the `arch` family).
2. For a new family, copy `distros/TEMPLATE.sh` to `distros/<family>.sh` and
   implement the contract functions (`ryoku_distro_system_update`,
   `ryoku_distro_prereqs`, `ryoku_distro_install_full`).

The shared manifests (`install/ryoku-*.packages`) are the only package data; an
adapter only changes how packages get installed. Nix, if added later, is a separate
declarative path (flake + home-manager), not an imperative adapter here.
