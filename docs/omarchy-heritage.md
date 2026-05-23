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
| Historical migrations under `migrations/` | Existing installs may have old state from earlier compositor, shell, Waybar, Mako, SwayOSD, Tofi, Walker, Elephant, and Omarchy-era phases. Those migrations must stay readable and idempotent. |
| Cleanup-only filesystem paths | Some install and migration scripts still remove old Omarchy files, services, boot assets, and state directories. These references delete legacy state; they do not create new Omarchy state. |
| Compatibility environment fallbacks | A small number of legacy `OMARCHY_*` variables are accepted as fallbacks where old installs or old shells may still provide them. Ryoku-owned `RYOKU_*` variables are canonical. |
| Webapp cleanup matchers | Some cleanup commands recognize old `omarchy-*` desktop-file launchers so user-created webapps can be removed safely. |
| External theme and package identifiers | Some third-party theme IDs, package names, and URLs include `omarchy` because changing them would point to a different external object or break migration cleanup. |
| ASCII terminal screensaver | The terminal/TTE screensaver was adopted as a Ryoku feature and is kept under Ryoku commands, config, and window classes. |
| Historical plan/spec documents | Files under `docs/superpowers/` describe previous work sessions. They are records, not current runtime instructions. |

## What No Longer Ships As The Active Desktop

The current source track is Hyprland with the Ryoku shell. Earlier compositor
and shell transition work remains only as legacy migration context unless a
file explicitly marks it as active.

The following names should only appear as historical, cleanup, compatibility,
or external identifier references:

- Retired compositor session defaults and window rules.
- Waybar status bar config.
- Mako notification defaults.
- SwayOSD styling.
- Tofi, Walker, and Elephant launcher configs.
- Retired prototype runtime trees.
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
| `config/hypr/` | Current Hyprland compositor config source. |
| `docs/keybindings.md` | Current user-facing keyboard reference. |


## Active Ryoku Core Capabilities

The migrated core is not just legacy baggage. It is the system control layer that the shell should call instead of reimplementing system behavior in QML.

Current core domains, based on the `ryoku-*` command namespace:

- **Install and update lifecycle:** `ryoku-update-*`, `ryoku-reinstall-*`, `ryoku-channel-*`, `ryoku-branch-set`, release/version helpers, snapshots, rollback, migrations, and doctor checks.
- **Package and app management:** `ryoku-pkg-*`, app installers, profile installers, webapp install/remove, Chromium/Helium helpers, Steam, Tailscale, NordVPN, Dropbox, Docker DBs, developer environment installers.
- **Compositor and desktop repair:** Hyprland config refresh, keybinding docs, shell restart/recovery, default app migration, terminal launchers, systemd service repair, session recovery, update log analysis.
- **Theming and appearance outside QML:** wallpaper list/cache/apply/search, theme install/remove/set/refresh, font list/set/install, cursor list/set/install, keyboard theme setters, GTK/KDE/terminal/editor/app template refreshers, SDDM and lockscreen preview refreshers.
- **Hardware and power:** hardware detectors, hybrid GPU toggle, touchpad and haptic touchpad, battery status and charge limit helpers, brightness commands, power profiles, suspend and hibernation setup/removal, idle/nightlight/notification toggles.
- **Network and security:** Wi-Fi/bluetooth launchers and restarts, firewall, hosts editing, OpenVPN import/remove/rename, Tailscale install, DNS setup, FIDO2/fingerprint setup, sudo reset/passwordless toggle.
- **Media and productivity utilities:** audio effects, volume and microphone commands, screen recording, OCR, Google Lens, color picker, QR scan, voice typing, music daemon/profile helpers, TUI and launcher helpers.

Design implication: if a settings page controls one of these domains, the shell should be a client of the core. The usual pattern is:

```text
Settings control -> QML service/IPC adapter -> ryoku-* command -> state/config file -> shell observes result
```

Only keep the behavior fully inside QML when it is genuinely shell-local, such as panel visibility, an overlay mode, layout density, or a visual token.

## Shell vs Core Responsibility Split

Use this split when deciding where new work belongs:

- **Shell owns:** visible panels, overlays, OSDs, visual tokens, animation, layout, user interaction, previews, and live display of status.
- **Core owns:** packages, services, filesystem config, migrations, rollback, hardware toggles, network/system commands, compositor config, and anything requiring elevated permissions.
- **Shared contract:** stable config paths, state files under `$RYOKU_STATE_PATH`, command JSON or JSONL output when a setting needs structured data, and narrow IPC targets for shell actions.

If a feature needs both, build the core command first, then bind the shell UI to it. This prevents the shell from becoming a pile of privileged one-off scripts and keeps terminal users able to perform the same actions without the settings app.


## How To Review A New Reference

When a new `omarchy`, old-compositor, or old-shell reference appears, classify
it before changing it:

1. **Attribution:** keep it if it preserves copyright, license, or upstream
   credit.
2. **External identifier:** keep it if the string is a package, extension,
   repository, or URL that exists under that name.
3. **Cleanup:** keep it if it only removes or migrates old installed state.
4. **Historical doc:** keep it if the file is a dated plan/spec record.
5. **Active runtime:** rename or remove it. Active runtime should use Ryoku,
   Hyprland, and Ryoku-shell surfaces.

The public docs should describe active Ryoku behavior first. Historical names
belong here, in `docs/rebrand-inventory.md`, or in dated plans.
