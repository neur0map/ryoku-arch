# Release / Packaging Changelog

## Unreleased

### Fixed
- Audio no longer crackles and pops under load. `ryoku-desktop` now depends on
  `rtkit` and enables `rtkit-daemon` (once, on install and on upgrade, the same
  one-shot pattern as `bluetooth.service`), and the installer enables it too. Without
  it PipeWire could not get realtime scheduling (no realtime group, no PAM limits),
  so its audio thread ran `SCHED_OTHER` and got preempted during a Discord video
  call or over Bluetooth, underrunning the buffer into crackling. rtkit hands that
  thread realtime priority over D-Bus with no per-user setup. This is the real fix
  behind "EasyEffects made it stop": raising the buffer only masked the missing
  realtime scheduling.
- Bluetooth calls are less telephone-muffled and music is higher quality.
  `ryoku-desktop` ships a system WirePlumber drop-in
  (`/etc/wireplumber/wireplumber.conf.d/51-ryoku-bluetooth.conf`) that enables mSBC
  wideband speech for the headset (HFP) profile and prefers hi-fi A2DP codecs
  (LDAC, AptX, AAC) over plain SBC. Classic Bluetooth still cannot carry hi-fi
  output and a mic at once, so a call is not A2DP quality, but this is the best the
  profile allows. Users can override it in `~/.config/wireplumber/wireplumber.conf.d/`.

### Added
- unstable-dev climbs its own version now. A new `unstable-version-bump`
  workflow bumps `VERSION` one patch on every push, rolling to the next minor
  once the patch passes 9 (`0.1.9` -> `0.2.0`), and keeps the hand-set beta line
  (`0.1.2-beta.16` -> `0.1.3-beta.16` -> ...), so the base grows with the work
  instead of sitting still until a release. `main` is never touched here; it
  holds its version until unstable-dev merges in and adopts whatever the base
  has reached. A push that hand-edits `VERSION` (a new beta, minor, major, or
  base) is taken as deliberate and left alone. `ryoku-release-bump` gained a
  `roll` bump (patch, carrying to minor past 9) and a `keep` stage (bump the
  number, keep the pre-release suffix).
- `ryoku-rashin` ships the `rashin` terminal command as a `/usr/bin/rashin`
  symlink to the daemon binary (argv0 dispatch, the busybox pattern), and
  `ryoku-desktop` lays `ryoku/apps/fish/conf.d/rashin.fish` into the base
  config tree so materialized desktops get the interactive wrapper, the Alt+R
  binding, the learning hook, and the recipes loader. Both stay inert until
  Rashin is enabled. See the ryoku/apps and docs changelogs.
- `ryoku-desktop` ships the PipeWire drop-in (`ryoku/apps/pipewire/`) in the
  base config tree, so materialized desktops get audio that follows a newly
  connected device (see the ryoku/apps changelog).
- `release/packages/ryoku-rashin/`: a PKGBUILD for the optional Ryoku Rashin
  daemon (`ryoku-rashin`), built from the in-repo `ryoku/rashin/backend` with
  `CGO_ENABLED=0 go build -trimpath` like `ryoku-hub`; the build needs network
  for its one module dependency (`github.com/coder/websocket`). `ryoku-desktop`
  now depends on it, so the binary ships with the desktop but stays inert until
  the user enables it (optional means not running, not absent). It carries no
  runtime depends: Hermes is per-user opt-in, and kitty and xdg-open come with
  the desktop.
- `ryoku-rashin` pre-indexes the monorepo at package build: `build()` runs the
  freshly built binary's `repo-index` over the release tree and `package()`
  installs the snapshot to `/usr/share/ryoku/rashin/ryoku-repo.md`, so the
  installed target (which has no checkout) ships with the source map its agent
  vault folds in on every reindex.
- `ryoku-desktop` ships the Nautilus stash menu extension
  (`ryoku/apps/nautilus/ryoku-stash-menu.py`) to
  `/usr/share/nautilus-python/extensions/`, so the file-manager Install / Compress
  / LocalSend actions load for every user with no per-user materialize step.
- `ryoku-desktop` ships the first-party GUI apps (`ryovm`, `ryowalls`) via a
  generic apps loop: each `apps/<name>/quickshell` config, its `bin/` and Go
  helpers (e.g. `ryovm-fetch`), its `.desktop`, and its `logo.svg` as the launcher
  icon under `/usr/share/icons/hicolor/scalable/apps/<name>.svg`. App marks carry
  an intrinsic `width`/`height` so Qt's icon engine renders them (a `viewBox`-only
  SVG resolves but draws blank). `go` is a make-dependency for the helpers. The
  `.install` refreshes the hicolor icon cache and desktop database on
  install/upgrade. The old single-purpose `ryoku-vm` launcher is removed (its
  passthrough VM is configured from Ryoku Settings > GPU; general VMs run in ryovm).
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
- `ryoku-desktop`: make `nautilus` + `nautilus-python` hard depends instead of
  optional. The Ryoku stash actions (Install/Compress/Send with Ryoku) ship as a
  nautilus-python extension, but nautilus-python was only an optdepend and
  `pacman -Syu` never pulls optdepends, so existing boxes updated without it and
  the right-click menu never loaded. As a depend it reaches every path: pacstrap
  via `base.packages`, the standalone installer transitively, and existing boxes
  on `ryoku update` since the auto-generated `pkgver` bumps.
- Installs no longer fail with "Maximum file size exceeded" from repo.ryoku.dev
  (issue #21). The publish workflow uploaded the repo in one `rclone sync` with no
  ordering guarantee, so a partial or mid-flight run could leave the live `ryoku.db`
  naming a package whose `.sig` was not up yet; pacman fetches that missing `.sig`
  as an HTML 404 that overruns its signature size cap and aborts under
  `SigLevel=Required`. Publish now goes packages + sigs first, db last, prune last,
  so the db is never ahead of what it references.
- `ryoku-desktop`: depend on `bluez` + `bluez-utils`, and one-shot enable + start
  `bluetooth.service` from the `.install` (guarded by a marker under
  `/var/lib/ryoku` so a user who later disables the service stays disabled
  across upgrades; inside the installer chroot only the enable symlink lands).
  Heals installs that predate the bluez dependency, where the Hub/pill
  Bluetooth UI sat dead against a missing daemon.
- `ryoku-desktop`: depend on `papirus-icon-theme` and install `qt6ct/qt6ct.conf`
  in place of the removed `kdeglobals`, matching the shell's switch back to the
  `qt6ct` Qt platform theme so packaged desktops resolve app icons (the
  launcher's all-apps grid showed broken-image placeholders under the
  never-functional `kde` theme). The dependency is the single source that reaches
  every path: pacstrap already pulls it via `base.packages`, the standalone shell
  installer gets it transitively (it installs `ryoku-desktop`), and existing
  boxes pick it up on `ryoku update` since the auto-generated `pkgver` bumps.
- `ryoku` package now depends on `pacman-contrib`: `ryoku status` (the data the
  Hub and update island read for "check for updates") uses `checkupdates` to
  detect pending updates, but it was not installed on Ryoku systems, so the
  update UI silently reported no updates. Bumped `ryoku` to `pkgrel=2`. Surfaced
  by a full end-to-end qemu desktop update test.
- `ryoku-desktop`: ship the fastfetch emblem
  (`ryoku/assets/brand/fastfetch-emblem.png`) into the base config tree at
  `fastfetch/fastfetch-emblem.png`, so `ryoku materialize` lays it beside
  `config.jsonc` on every update. The readout's logo is a fixed asset the config
  references, but it only reached machines as an installer-time brand-asset seed
  under `~/.local/share`, never through an update; when the emblem was redrawn and
  renamed, updated desktops pointed at a file they never got and fastfetch
  silently fell back to the Arch logo. It now rides the same delivery as the
  config it serves.

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
