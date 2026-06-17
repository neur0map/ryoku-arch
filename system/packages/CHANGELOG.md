# Changelog: system/packages/

## Unreleased

### Added
- `base.packages`: the curated base set the installer pacstraps.
- `hardware.packages`: per-profile CPU microcode (`[amd]`, `[intel]`). GPU drivers
  come from `system/hardware/drivers/*.sh`, which the installer runs in the target.
- `aur.packages`: AUR add-ons (Limine hooks, Bibata cursors, AUR helper).
- `dev.packages`: optional developer toolchains.
