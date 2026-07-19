# Changelog

Notable changes to the repository as a whole. Each tree keeps its own changelog
for finer detail.

## Unreleased

### Added
- **User edits live in a `user_edits` overlay, separate from Ryoku-owned config.**
  `~/.config/ryoku/user_edits` mirrors `~/.config` and is laid over the base on
  every `ryoku materialize`/deploy, so a file there wins while the base (the
  restore point) still delivers every fix and addition underneath. Overriding by
  overlay (a last-loaded `user.lua`/`settings.lua`/`user.conf`) keeps upstream
  fixes flowing; forking a whole file opts out for that one file, and `ryoku
  doctor` reports the drift. `ryoku reset [path]` reverts an override; `ryoku
  recovery` wipes the overlay and the Hub's stores back to shipped defaults.
  Ryoku Settings writes its output into the overlay too. See `docs/updates.md`.
- Update-delivery guard: `bin/ryoku-dev-verify-delivery` fails a commit when a
  `ryoku/apps` config reaches no user (shipped by no package, installer, or
  deploy path) and reports how far `main` lags `unstable-dev`. Wired into
  pre-commit, post-commit, and a Delivery check workflow. `docs/updates.md`
  documents the update, materialize, and doctor flow and the delivery contract.
- Fresh repository layout: `installation/`, `system/`, `ryoku/`, each with a README
  and changelog.
- A working installer (Go TUI plus a bash backend) that partitions, optionally
  encrypts with LUKS, installs the base system, configures it, deploys the desktop,
  and sets up Limine.
- A plain Hyprland desktop with kitty, fastfetch, fish, and nautilus, an SDDM
  greeter using the qylock clockwork theme, and Limine with Ryoku branding.
- A `shell/` tree: the full Ryoku shell (a Quickshell bar, panels, launcher, lock,
  and screenshot tool) driven by one Go IPC daemon, `ryoku-shell`, that supervises
  the components and handles every shell control command. Imported and de-branded
  as a base; not yet wired into the installer.
- A shell plugin system: third-party widgets a user places where they like. A
  plugin ships a service plus one adaptive `content/Widget.qml` (glyph / compact
  / full densities); the shell owns the layer, shape, size, and motion of each
  host (frame popout, desktop widget; topbar glyph, window, island to follow),
  so plugins always read as native. Managed in Ryoku Settings -> Plugins
  (enable + pick a host), discovered from `~/.local/share/ryoku/plugins` and the
  user's `plugins.json`, with the signature kit shipped as the `Ryoku.PluginKit`
  QML module. The `ryoku-extras` `plugin` bundle items now install instead of
  being deferred. The legacy `wallhaven` plugin is reworked as the worked
  example.

### Fixed
- Limine now shows the generated boot menu: the branded config moved from
  `/boot/limine/limine.conf` (which Limine scans first, shadowing everything
  `limine-entry-tool` generates into `/boot/limine.conf`: the UKI tree and the
  snapper Snapshots submenu) to `/boot/limine.conf` itself, and the EFI binary
  moved onto the path the tool's pacman hook refreshes
  (`EFI/limine/limine_x64.efi`), so the booted bootloader stops aging against
  the installed package. `ryoku doctor` migrates existing installs in place.

### Notes
- The previous Arch tree stays on the `main` branch as reference. The NixOS work
  moved to its own repository.
