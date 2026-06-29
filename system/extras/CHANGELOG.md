# Changelog: system/extras/

## Unreleased

### Added
- The extras subsystem that backs the Hub's Extras section: helpers shipped to
  `/usr/bin` by `ryoku-desktop` that install, remove, and report the optional
  bundles defined in the `ryoku-extras` catalogue.
- `ryoku-extras-install`: the actuator. Reads a bundle definition from the
  catalogue cache, detects each item, routes `package` items to the official
  repos (`ryoku-pkg-add`) or the AUR (`ryoku-pkg-aur-add`), runs `script` items'
  installers from the catalogue, defers `plugin` items to the shell, and publishes
  a per-bundle JSON report under `$XDG_RUNTIME_DIR/ryoku-extras/` that the Hub
  watches. `status` queries without changing anything; a bundle's
  `"requires": ["multilib"]` is satisfied before its packages are routed.
  `RYOKU_EXTRAS_DRYRUN=1` prints the plan and touches nothing.
- `ryoku-pkg-add`, `ryoku-pkg-aur-add`, `ryoku-pkg-remove`: thin pacman and
  AUR-helper wrappers for repo installs, AUR installs, and removals.
- `ryoku-pkg-multilib`: idempotently enables the `[multilib]` repo for bundles
  that need 32-bit packages (Gaming, for Steam and the lib32 libraries).
- `ryoku-pkg-cachyos`: idempotently adds the `[cachyos-v3]` repository (CachyOS
  key, x86-64-v3 only, additive, without the baseline `[cachyos]` repo or its
  forked pacman) so the CachyOS Kernel bundle can install `linux-cachyos`
  through pacman.
- `ryoku-extras-install`: satisfy `"requires": ["cachyos"]` via
  `ryoku-pkg-cachyos`, and abort with a "run ryoku update" message on any
  unrecognized requirement instead of skipping it (which would mis-route the
  bundle's packages to an AUR source build).
- `ryoku-cmd-present`: the single command-presence test shared by the actuator
  and the catalogue's installer scripts.
