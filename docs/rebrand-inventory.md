# Rebrand Inventory

This is the maintainer-facing ledger for Omarchy-to-Ryoku and old-desktop
references. For the user-facing explanation, see `docs/omarchy-heritage.md`.

## Current Rule

Active runtime, installer, and public docs should use Ryoku-owned names and the
current Niri session language.

Old names are allowed only when they are:

- Legal attribution.
- Git history or upstream-tracking context.
- Cleanup for existing installs.
- Compatibility input accepted from old installs.
- External package, extension, theme, or repository identifiers.
- Historical records under `docs/superpowers/`.

## Canonical Ryoku Surfaces

| Surface | Current Canonical Form |
| --- | --- |
| Commands | `ryoku-*` |
| Repo path | `$RYOKU_PATH`, normally `~/.local/share/ryoku` |
| Config path | `$RYOKU_CONFIG_PATH`, normally `~/.config/ryoku` |
| State path | `$RYOKU_STATE_PATH`, normally `~/.local/state/ryoku` |
| User config | `~/.config/ryoku` |
| User state | `~/.local/state/ryoku` |
| Active compositor config | `config/niri/` |
| Current keybinding docs | `docs/keybindings.md` |
| Public legacy explanation | `docs/omarchy-heritage.md` |

## Remaining Intentional Omarchy References

| Bucket | Examples | Why It Stays |
| --- | --- | --- |
| Attribution | `LICENSE`, `NOTICE`, `CREDITS.md` | Required credit for upstream work and license history. |
| Upstream tracking | `docs/maintenance.md`, `.githooks/pre-push`, `upstream-baseline` | Lets maintainers inspect and cherry-pick upstream work without publishing upstream mirror branches. |
| Cleanup-only paths | installer cleanup scripts, hibernation/boot cleanup migrations | These remove old files from systems that previously had Omarchy state. |
| Compatibility inputs | selected `OMARCHY_*` fallbacks and old webapp launcher matchers | Older installs and user-created desktop files may still contain those names. |
| Historical migrations | `migrations/17*.sh` | Migrations are append-only operational history; rewriting old migrations can break existing installs. |
| External identifiers | VS Code extension IDs such as `Bjarne.vantablack-omarchy`, old theme asset filenames | These names refer to external objects or bundled assets and are not active Ryoku branding. |

## Old Desktop References

Hyprland, Waybar, Mako, SwayOSD, Tofi, Walker, Elephant, Brain Shell, and
Noctalia references should not describe the active desktop. They are acceptable
only in these places:

- Historical migrations for older installs.
- Cleanup logic that removes old config or services.
- Historical plan/spec files.
- External package or theme identifiers.
- This rebrand ledger and `docs/omarchy-heritage.md`.

The current active desktop docs should point to Niri, the Ryoku shell, and
`config/niri/config.d/70-binds.kdl`.

## Audit Commands

Use these from the repo root when reviewing a rebrand or old-desktop cleanup:

```bash
rg -n 'omarchy|OMARCHY' --hidden --glob '!.git/*' --glob '!docs/superpowers/**'
rg -n 'Hyprland|hyprland|Waybar|waybar|Mako|mako|SwayOSD|swayosd|Tofi|tofi|Walker|walker|Elephant|elephant|Brain Shell|Noctalia' --hidden --glob '!.git/*' --glob '!docs/superpowers/**'
```

Classify each finding before editing. Do not remove compatibility or cleanup
references just to make `rg` empty.

## Close-Out Status

- [x] Runtime commands moved to `ryoku-*`.
- [x] Active config/state/share paths moved to Ryoku-owned namespaces.
- [x] Omarchy package repo and keyring removed from active install path.
- [x] Boot branding, Plymouth assets, logo assets, and Ryoku font moved to
  Ryoku-owned names.
- [x] Active desktop source switched to Niri.
- [x] Public docs updated to treat old desktop names as legacy or historical.
- [ ] Fresh Niri ISO build and boot verification.
- [ ] Rebrand current shell and greeter assets from their upstream defaults to
  Ryoku visuals.
- [ ] Add CI guard for new unclassified `omarchy` references.
- [ ] Remove compatibility wrappers/fallbacks after a documented deprecation
  window.
