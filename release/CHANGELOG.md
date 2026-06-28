# Release / Packaging Changelog

## Unreleased

### Added
- `ryoku-desktop` ships the Ryoku VM launcher icon to
  `/usr/share/icons/hicolor/scalable/apps/ryoku-vm.svg`, so the **Ryoku VM** app
  entry shows the brand mark instead of a generic placeholder.
- `ryoku-desktop` now ships the `Ryoku.PluginKit` QML module (to
  `/usr/lib/qt6/qml/Ryoku/PluginKit`, beside `Ryoku.Blobs`) and the
  `ryoku-plugins-place` helper on PATH, so shell plugins find the signature kit
  and persist their placement on an installed system. The `plugins` Quickshell
  config rides along in the packaged `quickshell/` tree.

### Changed
- The desktop packages built from the monorepo (`ryoku-desktop`, `ryoku`,
  `ryoku-shell`, `ryoku-hub`, `ryoku-blobs`) are now versioned per build as
  `<core>.r<commit-count>.g<short-sha>`: `bin/ryoku-release-version --pkgver`
  computes it and `build-repo.sh` injects it as `RYOKU_PKGVER`, which each PKGBUILD
  reads. Every published build is then a strictly newer, commit-identifiable pacman
  version, so `ryoku update` (pacman -Syu) delivers commits pushed after a user's
  ISO instead of seeing a static `0.1.0-3` forever, and `ryoku status` and the Hub
  show the exact commit. `gpk` and `ryoku-keyring` keep their own versions (pinned
  upstream release, key-rotation date).
- Rebuilt the `[ryoku]` repo for the new desktop shell work: `ryoku` to
  `pkgrel=3` (the CLI gains `ryoku recovery`, a last-resort restore) and
  `ryoku-desktop` to `pkgrel=2` (ships the reworked Hub shell-settings editor
  and the live, config-driven desktop visualiser). Republished so a fresh
  install and `ryoku update` both deliver the new shell.

### Fixed
- `ryoku` package now depends on `pacman-contrib`: `ryoku status` (the data the
  Hub and update island read for "check for updates") uses `checkupdates` to
  detect pending updates, but it was not installed on Ryoku systems, so the
  update UI silently reported no updates. Bumped `ryoku` to `pkgrel=2`. Surfaced
  by a full end-to-end qemu desktop update test.

### Added
- `release/packages/` PKGBUILDs for the Ryoku desktop, built from the in-repo
  checkout: `ryoku-keyring` (ships the release signing key + trust), `ryoku-shell`,
  `ryoku-hub`, `ryoku`, `ryoku-blobs`, and the `ryoku-desktop` umbrella (configs to
  `/usr/share/ryoku/config`, helper scripts to `/usr/bin`, runtime depends).
- `release/packages/gpk/`: ship GlazePKG (`gpk`), the RyokuArch package manager,
  as a first-class signed `[ryoku]` package (repackaged from the pinned upstream
  release binary, `provides`/`replaces` the AUR `gpk-bin`). `ryoku-desktop` now
  depends on it (`pkgrel=3`), so a fresh install and `ryoku update` always deliver
  `gpk` through pacman instead of the best-effort post-install AUR build.
- `release/repo/build-repo.sh`: builds + signs every package and assembles the
  signed `[ryoku]` pacman database, laid out for `https://repo.ryoku.dev/stable/$arch`
  (real db files, not symlinks, for R2).
- `.github/workflows/publish-repo.yml`: builds, signs, and publishes the `[ryoku]`
  repo to Cloudflare R2 on a push to `main` (the user update channel) and on
  release tags (`v*`), plus manual dispatch; `unstable-dev` never publishes. It
  checks out full history (fetch-depth: 0) so the package version can carry the
  commit count.
- `keys/ryoku-release-key.pub.asc`: the Ryoku release public key
  (`releases@ryoku.dev`, ed25519, fpr `EB6D 3C0F 55A7 B3CA BA6B 2838 847B 274F
  025D D6E3`).

### Verified
- `build-repo.sh` builds + signs all 10 package artifacts and a signed `ryoku.db`
  locally; the db and packages verify as "Good signature" against the release key.
