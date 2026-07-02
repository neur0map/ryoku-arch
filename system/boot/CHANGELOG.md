# Changelog: system/boot/

## Unreleased

### Fixed
- `limine/limine.conf` documents its real deploy target: `/boot/limine.conf`
  (the ESP root), the one config `limine-entry-tool` manages. The old comment
  described `/boot/limine/limine.conf`, a location Limine scans FIRST, so a
  config there shadows every generated entry (UKI tree, snapshots submenu).
- `limine/limine.conf`: `default_entry: 2`, matching the tool-managed menu
  (entry 1 is the `/+Ryoku` directory, which Limine refuses to autoboot; 2 is
  the newest UKI inside it). The installer rewrites it to 1 while the menu is
  still the flat placeholder. The placeholder path now names the UKI the hook
  actually builds (`ryoku_linux.efi`, from `CUSTOM_UKI_NAME="ryoku"` + the
  `linux` pkgbase), not the never-produced `ryoku.efi`.
- `limine/default.conf`: comment named the shadow path; now points at
  `/boot/limine.conf`.

### Added
- `limine/limine.conf`: Ryoku-branded Limine config (branding string, orange
  accent, Greek Noir palette, timeout, default UKI entry placeholder).
- `limine/default.conf`: UKI build settings (TARGET_OS_NAME, ESP_PATH,
  ENABLE_UKI, CUSTOM_UKI_NAME, snapshot entries, `quiet splash` cmdline).
- `plymouth/ryoku/`: vendored Ryoku Plymouth splash (manifest, script, assets).
- `mkinitcpio/ryoku.conf`: HOOKS drop-in with `plymouth` and `kms`; `encrypt`
  documented as LUKS-only.
