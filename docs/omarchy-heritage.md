# Foundation And Heritage

Ryoku is a premium Arch workstation environment. Its runtime and command
surface are Ryoku-owned, while selected ideas were adapted from upstream
projects for speed and ergonomics.

## Where Ryoku Comes From

Ryoku uses three clear sources:

- **Omarchy** for install architecture, command patterning, and migration-minded
  maintenance.
- **Shell interaction patterns** that were adapted into Ryoku-owned layout and
  plugin surfaces.
- **Ryoku core direction** for naming, branding, defaults, and command ownership.

That means you should read docs as:

- Current runtime behavior = Ryoku-owned.
- Historical names = historical, compatibility, or external identifiers.

## What Still Remains

| Surface | Why It Remains |
| --- | --- |
| `LICENSE` and `NOTICE` attribution | Required attribution for inherited components and their open-source licenses. |
| `upstream` remotes and `upstream-baseline` history | Needed for selective cherry-picks and auditability. |
| Historical migrations under `migrations/` | Older installs can still contain legacy state from previous compositor or shell generations. Migrations must stay readable and idempotent. |
| Cleanup-only filesystem paths | Some install and migration scripts still remove old state from deprecated runtimes. These commands are cleanup only and do not represent active defaults. |
| Compatibility environment fallbacks | A small set of `OMARCHY_*` variables remains as compatibility bridge behavior for legacy scripts and older system states. |
| External theme/package identifiers | Some third-party IDs include `omarchy` or legacy names because those references point to external objects that still exist. |
| Historical plan/spec documents | `docs/superpowers/` is historical context, not live runtime documentation. |

## What Does Not Ship As Active Runtime

These names only belong in historical context unless another section explicitly
re-activates them:

- Waybar configuration.
- Mako defaults.
- SwayOSD defaults.
- Tofi, Walker, and Elephant launchers.
- Prototype runtime trees used during transition.
- Omarchy package repo/keyring/mirror URLs and old boot branding assets.

## Current Ryoku User-Facing Surfaces

| Ryoku Surface | Current Meaning |
| --- | --- |
| `ryoku-*` commands | Canonical command namespace. |
| `$RYOKU_PATH` | Canonical installed repo path. |
| `$RYOKU_CONFIG_PATH` | Canonical Ryoku config path. |
| `$RYOKU_STATE_PATH` | Canonical Ryoku state path. |
| `~/.config/ryoku` | User Ryoku config and hook namespace. |
| `~/.config/ryoku/shell.json` | Shell configuration and feature toggles. |
| `~/.local/share/ryoku` | Installed Ryoku source tree. |
| `~/.local/state/ryoku` | Runtime state and migration markers. |
| `config/hypr/` | Current Hyprland compositor config source. |
| `docs/keybindings.md` | Current user-facing keyboard reference. |

## Active Core Domains (for shell integrations)

The key rule is simple: settings should drive config and commands, not own
system behavior directly.

- **Install and update lifecycle:** `ryoku-update-*`, `ryoku-reinstall-*`, `ryoku-channel-*`, release/version helpers, snapshots, rollback, migrations, and doctor checks.
- **Package and app management:** package helpers, profile installers, webapp install/remove, Chromium/Helium, Steam, Tailscale, NordVPN, Docker, and developer environment installers.
- **Compositor and desktop repair:** Hyprland config refresh, keybinding docs, shell restart/recovery, default app migration, terminal launchers, systemd repair.
- **Theming and appearance outside QML:** wallpaper cache/list/apply/search, theme tooling, font and cursor management, GTK/KDE/template refreshers.
- **Hardware and power:** hardware detection, hybrid GPU handling, touchpad behavior, battery/charge helpers, brightness, power profiles, suspend/hibernation, idle and notification toggles.
- **Network and productivity:** Wi-Fi/bluetooth launchers, firewall and host tooling, OpenVPN import/rename, Tailscale, DNS setup, sudo helpers, polkit flows, security-sensitive workload bundles as plugin lanes.
- **Media and utilities:** volume and microphone controls, screen capture helpers, OCR, Google Lens, color picker, QR scan, voice typing.

Use this contract for new shell work:

```text
Settings control -> Ryoku service/IPC adapter -> ryoku-* command -> state/config -> shell consumers
```

Only keep behavior inside QML for UI-local concerns (layout, rendering, overlays,
interaction, and in-shell previews).

## How To Review A New Reference

Classify each historical name before changing it:

1. **Attribution:** keep it if it preserves required notices and upstream credit.
2. **External identifier:** keep package/repo IDs that must stay aligned with
   published upstream objects.
3. **Cleanup:** keep references that only remove legacy state.
4. **Historical doc:** keep dated planning/spec material for institutional memory.
5. **Active runtime:** anything that affects current behavior belongs in Ryoku-owned surfaces and should not leak historical naming.

For active docs and migration work, `docs/omarchy-heritage.md` should be the first stop.
