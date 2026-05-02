# Omarchy Heritage

Ryoku began as an Omarchy-derived Arch environment, then moved its active
runtime, commands, config paths, install flow, and branding onto Ryoku-owned
surfaces. This document explains what remains so users and contributors can
tell the difference between active Ryoku behavior and intentional historical
or compatibility references.

## What Still Remains

| Surface | Why It Remains |
| --- | --- |
| `LICENSE` and `NOTICE` attribution | Required attribution for the original Omarchy project and its MIT license. |
| Git history, upstream remotes, and `upstream-baseline` | Needed to audit ancestry and cherry-pick useful upstream fixes without merging upstream wholesale. |
| Historical migrations under `migrations/` | Existing installs may have old state from earlier Hyprland, Waybar, Mako, SwayOSD, Tofi, Walker, Elephant, and Omarchy-era phases. Those migrations must stay readable and idempotent. |
| Cleanup-only filesystem paths | Some install and migration scripts still remove old Omarchy files, services, boot assets, and state directories. These references delete legacy state; they do not create new Omarchy state. |
| Compatibility environment fallbacks | A small number of legacy `OMARCHY_*` variables are accepted as fallbacks where old installs or old shells may still provide them. Ryoku-owned `RYOKU_*` variables are canonical. |
| Webapp cleanup matchers | Some cleanup commands recognize old `omarchy-*` desktop-file launchers so user-created webapps can be removed safely. |
| External theme and package identifiers | Some third-party theme IDs, package names, and URLs include `omarchy` because changing them would point to a different external object or break migration cleanup. |
| Historical plan/spec documents | Files under `docs/superpowers/` describe previous work sessions. They are records, not current runtime instructions. |

## What No Longer Ships As The Active Desktop

The current source track is Niri with the Ryoku shell. The old Hyprland default
session and its supporting runtime pieces are not the active desktop contract.

The following names should only appear as historical, cleanup, compatibility,
or external identifier references:

- Hyprland session defaults and window rules.
- Waybar status bar config.
- Mako notification defaults.
- SwayOSD styling.
- Tofi, Walker, and Elephant launcher configs.
- Brain Shell and Noctalia prototype runtime trees.
- Omarchy package repo, keyring, mirror URLs, and old branded boot assets.

## Current User-Facing Surfaces

| Ryoku Surface | Current Meaning |
| --- | --- |
| `ryoku-*` commands | Canonical command namespace. |
| `$RYOKU_PATH` | Canonical installed repo path. |
| `$RYOKU_CONFIG_PATH` | Canonical Ryoku config path. |
| `$RYOKU_STATE_PATH` | Canonical Ryoku state path. |
| `~/.config/ryoku` | User Ryoku config and hook namespace. |
| `~/.local/share/ryoku` | Installed Ryoku source tree. |
| `~/.local/state/ryoku` | Runtime state and migration markers. |
| `config/niri/` | Current compositor config source. |
| `docs/keybindings.md` | Current user-facing keyboard reference. |

## How To Review A New Reference

When a new `omarchy`, old-compositor, or old-shell reference appears, classify
it before changing it:

1. **Attribution:** keep it if it preserves copyright, license, or upstream
   credit.
2. **External identifier:** keep it if the string is a package, extension,
   repository, or URL that exists under that name.
3. **Cleanup:** keep it if it only removes or migrates old installed state.
4. **Historical doc:** keep it if the file is a dated plan/spec record.
5. **Active runtime:** rename or remove it. Active runtime should use Ryoku and
   Niri surfaces.

The public docs should describe active Ryoku behavior first. Historical names
belong here, in `docs/rebrand-inventory.md`, or in dated plans.
