# Ryoku rice (the shipped default config)

This is **the Ryoku rice**: the version-controlled default config that defines
how Ryoku ships. It lives under `shell/` alongside the integrated components
(`dashboard/`, `settingsgui/`) and the shell code, so there is exactly one path to edit
when you want to change how Ryoku looks or behaves out of the box.

| File | Role |
|---|---|
| `shell.json` | Ryoku-owned **native** shell defaults (`Ryoku.Config`, deep-merged fill-if-missing into `~/.config/ryoku/shell.json`). |
| `config-overrides.json` | **Narrow** desktop-config overlay force-merged into `~/.config/ryoku-shell/config.json` on every install **and** update (hotspot name, dock, enabled panels). Keep this small: it overrides the user on every update. |
| `branding-replacements.tsv` | Tab-separated `find<TAB>replace` map applied to the deployed shell tree (Ryoku branding strings/assets). |

`install/config/ryoku-shell-branding.sh` reads all three from here.

## The two rules (see `docs/ryoku-config-architecture.md`)

1. **Fresh install = the latest rice.** Every edit here ships in the next ISO.
2. **Existing users are only touched by `[global]` changes.** A broad rice change
   reaches existing users only via a `migrations/<unix-ts>.sh`; the narrow
   `config-overrides.json` set is the exception (force-applied every update).

Ryoku-owned *fill-if-missing* defaults (applied every update without overriding a
user's explicit choice) live in `apply_ryoku_owned_runtime_config_to_file()` in
`install/config/ryoku-shell-branding.sh`.

## Checking divergence

`ryoku-doctor-rice` reports where the live shell config
(`~/.config/ryoku-shell/config.json`) diverges from the force-managed rice keys,
so the "yours vs how Ryoku ships" split stays legible. Local edits to those keys
do not persist (they reset on the next update); change the rice here instead.
