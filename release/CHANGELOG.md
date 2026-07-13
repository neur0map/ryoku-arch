# Release / Packaging Changelog

## Unreleased

### Added
- Four new `[ryoku]` repo packages build the optional Hyprland compositor plugins
  the Hub can toggle, installed to `/usr/lib/hyprland/plugins/`:
  `hypr-dynamic-cursors`, `ryoku-hypr-plugins` (hyprbars + hyprfocus),
  `hyprglass`, and `imgborders`. Hyprland plugins are ABI-locked to the
  compositor, so each PKGBUILD's `prepare()` reads the build host's Hyprland
  version and checks out the matching plugin commit from upstream's `hyprpm.toml`
  (the same version map `hyprpm` uses); a rebuild always tracks whatever Hyprland
  the repo ships, with no manual commit bumps.
  `ryoku-desktop` depends on all four (pinned to its own version), so they reach
  installed machines through `ryoku update` and a toggle never faces a missing
  `.so`. The publish workflow installs the plugin build deps (hyprland,
  hyprcursor, pango, cairo, pkgconf) and skips the new self-repo packages in its
  official-repo dependency check.
- **`wallust` now ships from the `[ryoku]` repo** as a hard `ryoku-desktop`
  dependency, not the AUR. wallust is the wallpaper -> color palette generator the
  shell runs on every wallpaper change (`wallust run <image>` retints kitty,
  Hyprland, and the shell), so "match wallpaper" colors are load-bearing, not a
  best-effort extra. The AUR package pins a checksum against Codeberg's
  auto-generated source archive, which Codeberg regenerates non-reproducibly, so
  the pin drifts and `makepkg` fails the validity check for everyone: the break
  users hit, where colors stopped following the wallpaper because wallust would
  not install. The new PKGBUILD builds from a pinned upstream git commit, which
  sidesteps the archive, and `pacman -Syu` pulls it onto existing boxes on `ryoku
  update`. The publish workflow installs `rust` (cargo builds wallust) and skips
  wallust in its official-repo dependency check.
- **`ryomotion` ships from the `[ryoku]` repo**: Ryoku Motion, the screen-demo
  recorder and editor, built from the OpenScreen fork
  (github.com/neur0map/ryomotion) and rebranded to Ryo Motion. The PKGBUILD
  builds the Electron app from a pinned commit, fetching the fork's pinned node
  22 at build time (its npm 10 runs the electron/esbuild/sharp install scripts a
  newer npm blocks by default) and rebranding name, binary, and appId with
  electron-builder `--config` overrides. The fork now carries a `RYOKU_RECORD`
  studio mode: launched with its window hidden, it auto-records and opens the
  editor on stop, so the shell's recorder island is the only capture toolbar.
  Installs the unpacked app to `/opt/ryomotion` with a `/usr/bin/ryomotion`
  launcher, a `.desktop`, and hicolor icons; `build-repo.sh` picks it up by
  glob. `ryoku-desktop` depends on
  it, so it ships in the ISO and reaches boxes on `ryoku update`.

### Changed
- **`waifu2x-ncnn-vulkan` is now a hard dependency of `ryoku-desktop`** (moved out
  of optdepends), so ryoshot's Beautify HD ×2 export and ryowalls Enhance reach
  every user: `pacman -Syu` pulls it onto existing boxes on `ryoku update`, and it
  is in `system/packages/base.packages` for fresh ISO installs. An optdepend never
  installs on `-Syu`, so existing boxes would never have received it.

### Fixed
- **The portal file chooser renders dark in a dark session.** `gnome-themes-extra`
  is now a hard dependency of `ryoku-desktop`, so the `Adwaita-dark` GTK theme the
  Hyprland autostart selects (`gsettings gtk-theme`) actually exists on disk.
  Nothing pulled it in before, so the name resolved to nothing and every GTK3 app
  -- the `xdg-desktop-portal-gtk` file/upload dialog most visibly -- fell back to
  light. `pacman -Syu` pulls it onto existing boxes on `ryoku update`; it is also
  in `system/packages/base.packages` for fresh ISO installs.
- **A published package filename never changes bytes again.** makepkg is not
  reproducible (BUILDDATE alone reshuffles the compressed bytes), and every
  publish rebuilt the fixed-version packages (`gpk`, `ryoku-keyring`) and
  overwrote their live files in place, packages-first-db-last. Any client
  whose db, HTTP cache, or `.part` resume predated the newest overwrite hit
  pacman's size cap: "Maximum file size exceeded", the 2026-07-08 curl-install
  failures on `gpk-0.5.8-1` (and issue #21's second act). Three changes close
  it: `build-repo.sh` now adopts the mirror's bytes for any name it already
  serves and re-signs them (shipping a real change means a pkgrel bump, which
  changes the name); the publish workflow runs one at a time (concurrency
  group, never cancelled mid-upload); and a post-upload step verifies every
  file the served db lists exists at the recorded size with its `.sig`,
  failing the publish instead of user installs. `gpk` and `ryoku-keyring` got
  a one-time pkgrel bump so every poisoned cache and stale db converges on
  virgin filenames.
- **The desktop set moves in lockstep or not at all.** `ryoku-desktop` now pins
  its monorepo components (`ryoku-shell`, `ryoku-hub`, `ryoku-rashin`,
  `ryoku-blobs`, `ryoku`) to its own version: every publish rebuilds them all
  with one shared version, and the shell QML this package ships must never run
  against another release's compiled plugin or daemon. A partial upgrade now
  fails loudly instead of skewing silently. The package is also `x86_64` now,
  not `any`: it compiles Go helpers into the payload.
- **Publish CI verifies every hard dependency exists in the official repos.**
  Packages build with `--nodeps`, so a typo'd or AUR-only depends entry used to
  publish cleanly and then brick every user's next `pacman -Syu` with an
  unresolvable target (the Material Symbols font dep was one review away from
  exactly that). The publish now fails instead.
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
- `ryoku-desktop` hard-depends `ttf-material-symbols-variable`. The shell's whole
  pill/bar iconography is the "Material Symbols Rounded" font (`MaterialIcon.qml`);
  it was only in the pacstrapped base set, so a box that predates that addition
  never received it on `ryoku update` and every icon rendered as its ligature name
  ("wifi", "power_settings_new"). Official repo, so a hard depend pulls it onto
  existing boxes on the next update.
- `ryoku` and `ryoku-rashin` declare their optional tools: `lua` (the `luac`
  config-syntax pre-check the Hyprland doctor reconciler prefers) and `sqlite`
  (the `sqlite3` introspection the rashin agent uses). Both are guarded
  fallbacks, so absent them the feature degrades rather than breaks; they ride
  as optdepends, surfaced for the curious.
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
