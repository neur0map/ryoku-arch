# Release / Packaging Changelog

## Unreleased

### Fixed
- **Desktop feature tools now reach every box, not just the ISO.** `ddcutil`,
  `gpu-screen-recorder`, `wf-recorder`, `hyprsunset`, `wtype`, `tesseract`,
  `tesseract-data-eng`, `zbar`, `songrec`, `libqalculate`, `openrgb` and `upower`
  lived only in `system/packages/base.packages` (ISO pacstrap) or `optdepends`, so
  a packaged box on `ryoku update` and a shell-installer box never got them: the
  recorder, night light, dictation, OCR/QR, calculator, LED sync, battery readout
  and external-monitor (DDC/CI) brightness were silently dead. They are now hard
  `ryoku-desktop` depends, so the ISO, `ryoku update` and the shell installer
  converge. `tests/shell-tool-availability.sh` gained a reach check (every
  official-repo feature tool must be a hard depend) so the drift cannot recur.

### Added
- **`ryoku-desktop` ships DDC/CI i2c access and the `ryoku-i18n` tool.** The
  `system/hardware/ddc/` module-load (`/etc/modules-load.d/ryoku-i2c.conf`, loads
  `i2c-dev`) and udev rule (`/usr/lib/udev/rules.d/60-ryoku-i2c.rules`, `uaccess`)
  let `ddcutil` drive external-monitor brightness with no group setup; and
  `ryoku/ui/i18n-sync.py` installs as `/usr/bin/ryoku-i18n` for the Hub's
  Language > Generate with AI button and the autostart key-file seed.
- **`ryoku-desktop` ships the laptop clamshell policy.** The `ryoku-clamshell`
  helper lands on `/usr/bin` via the `system/hardware/*/ryoku-*` glob, and the
  logind drop-in `system/hardware/power/logind-ryoku-lid.conf` installs to
  `/etc/systemd/logind.conf.d/10-ryoku-lid.conf`; the `.install` reloads
  `systemd-logind` (session-safe) so the lid policy applies without a reboot.
  Closing the lid on AC power with an external display no longer suspends.
- **`ryoku-desktop` ships the decor art set to `/usr/share/ryoku/ryodecors`.** The
  `Decor` and `Placard` components render from `~/Pictures/ryodecors`; the package
  carries the shipped set so `ryoku doctor` can lay it there on update (the
  installer seeds a fresh box straight from the repo). Moved out of the `Ryoku.Ui`
  QML module, which no longer bakes the art (`ryoku/assets/ryodecors`).
- **`awww` now ships from the `[ryoku]` repo** as a hard `ryoku-desktop`
  dependency, not the AUR. awww (swww renamed upstream) is the animated wallpaper
  daemon the shell drives: `ryoku/shell/ipc/wallpaper.go` runs `awww img` on every
  wallpaper set and starts `awww-daemon` on demand, so a fresh desktop with no
  daemon shows no wallpaper at all and ryowalls can list images but set none. As
  an AUR-only optdepend it was skipped on offline installs and best-effort on a
  failed build, leaving boxes to heal it by hand with `ryoku doctor`. The new
  PKGBUILD builds both binaries from a pinned upstream git commit (default
  features, so no dav1d), and `ryoku-desktop` hard-depends on it, so `pacman -Syu`
  pulls it onto every install and existing box. The publish workflow gains `lz4`
  (awww's pkg-config build probe) and skips `awww` in its official-repo dependency
  check.
- **`ryoku-cursors` now ships from the `[ryoku]` repo** as a hard `ryoku-desktop`
  dependency, not the AUR. It packages the Bibata XCursor family (the theme
  `env.lua`/`autostart.lua` set as `XCURSOR_THEME`/`HYPRCURSOR_THEME` and the Hub
  cursor picker defaults to) into `/usr/share/icons`, built from the pinned
  upstream release tarball (GitHub assets are immutable, so the sha256 is pinned
  for real, GPL-3.0-or-later). As an AUR package (`bibata-cursor-theme-bin`) it
  installed only in the post-install AUR step -- skipped offline, best-effort on
  failure, and never revisited by `ryoku update` -- so a box could come up with no
  configured cursor and a lone fallback bitmap. It is removed from
  `system/packages/aur.packages` (single source of truth) and added, unpinned
  like `wallust`/`awww` (a fixed upstream version, not the monorepo `RYOKU_PKGVER`),
  to `ryoku-desktop`'s depends, so `pacman -Syu` pulls it onto every install and
  existing box.
- Four new `[ryoku]` repo packages build the optional Hyprland compositor plugins
  the Hub can toggle, installed to `/usr/lib/hyprland/plugins/`:
  `hypr-dynamic-cursors`, `ryoku-hypr-plugins` (hyprbars + hyprfocus),
  `hyprglass`, and `imgborders`. Hyprland plugins are ABI-locked to the
  compositor, so each PKGBUILD's `prepare()` reads the build host's Hyprland
  version and checks out the matching plugin commit from upstream's `hyprpm.toml`
  (the same version map `hyprpm` uses); a rebuild always tracks whatever Hyprland
  the repo ships, with no manual commit bumps. If upstream's map has no pin for
  the shipped Hyprland yet (its pins can lag the distro), `prepare()` falls back
  to the plugin's default-branch HEAD (as `hyprpm` does) instead of failing, so a
  Hyprland release that outpaces a plugin's pin table can't abort the `[ryoku]`
  publish over one optional plugin.
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
  electron-builder `--config` overrides. `ryomotion <file>` opens a clip straight
  in the editor, so the shell captures with gpu-screen-recorder + a synthesised
  cursor track and hands the clip here with auto-zoom intact.
  `ryomotion --edit` opens the editor straight to its import screen (the island's
  Edit action). Recording from inside the editor is native too: on Linux it
  captures with gpu-screen-recorder (a hard dependency) instead of OpenScreen's
  browser pipeline, falling back to the browser recorder only when gsr is absent.
  It holds a single-instance lock, so a repeat launch (another Studio recording,
  Edit, or clip open) reuses the running app instead of stacking another ~600 MB
  Electron process tree.
  Installs the unpacked app to `/opt/ryomotion` with a `/usr/bin/ryomotion`
  launcher, a `.desktop`, and hicolor icons; `build-repo.sh` picks it up by
  glob. `ryoku-desktop` depends on
  it, so it ships in the ISO and reaches boxes on `ryoku update`.
- **Webcam self-view overlay** replaces the mpv `ryoku-cmd-mirror` PiP. The 力
  deck's Mirror tile and the record island now toggle a shaped, draggable camera
  bubble on a Wayland layer surface, reshaped in place by Figma-style on-canvas
  handles: drag the bottom-right grip to any size/shape, the top-left dot for
  corner roundness, plus a flip toggle. Size, shape, flip and position persist to
  `~/.config/ryoku/camera.json`; it stays across workspace
  switches and gpu-screen-recorder captures it into recordings. The feed is a
  native `CameraFeed` item in the `ryoku-blobs` QML plugin, which now hard-depends
  on `qt6-multimedia` (linked at runtime, required to build) so the `.so` loads on
  `ryoku update`. The retired mpv script and its `float-webcam-mirror` Hyprland
  window rule are removed.

### Changed
- **`ryomotion` now ships a distinct Ryo Motion icon**, not the upstream
  OpenScreen artwork (`pkgrel` 11, so `pacman -Syu` upgrades existing boxes).
  The icon is a purpose-generated flat camera-aperture mark on Ryoku's dark tile
  in the brand orange, matching the ryowalls/ryovm set (not the generic Ryoku
  seal). The PKGBUILD bundles it (`ryomotion-logo.png`) and overrides the fork's
  assets at build time: it replaces the in-app empty-state and tray logo
  (`public/openscreen.png`, before `build-vite`, which vite copies into the
  bundle) and installs it as the app icon for every hicolor size, in place of the
  fork's green-aperture icons. It is a build-safe asset swap (a sha256-validated
  local PNG copied over an existing file), so it cannot fail the Electron build.
  The remaining "OpenScreen" i18n text (About/Project strings) and the recording
  HUD/launch island stay fork-source concerns.
- **The live (video) wallpaper backend now ships hard via `ryoku-shell`, not as
  GPU-picked `ryoku-desktop` optdepends.** `ryoku-shell` also builds and installs
  `ryoku-livewall`, the tiny C video-wallpaper daemon (it software-decodes a
  downscaled clip into `wl_shm` on a `wlr-layer-shell` surface, so ~40 MB RSS on
  any GPU vendor instead of mpv/mpvpaper's 300-700 MB), gaining `wayland`,
  `wayland-protocols`, and `ffmpeg` makedepends plus `ffmpeg` and `wayland`
  depends. `ryoku-desktop` drops its now-obsolete `phonto` (AMD/Intel VAAPI) and
  `mpvpaper` (NVIDIA NVDEC) optdepends, since the one backend reaches every box
  through the hard `ryoku-shell` dependency
  (`release/packages/ryoku-shell/PKGBUILD`,
  `release/packages/ryoku-desktop/PKGBUILD`).
- **`waifu2x-ncnn-vulkan` is now a hard dependency of `ryoku-desktop`** (moved out
  of optdepends), so ryoshot's Beautify HD ×2 export and ryowalls Enhance reach
  every user: `pacman -Syu` pulls it onto existing boxes on `ryoku update`, and it
  is in `system/packages/base.packages` for fresh ISO installs. An optdepend never
  installs on `-Syu`, so existing boxes would never have received it.
- **The publish is now gated on the container-install smoke test.** On every push
  to `main` (and on a release tag), `publish-repo.yml` first builds the packages,
  installs `ryoku-desktop`, and materializes a full config on Arch and CachyOS;
  the sign-and-upload job `needs` that gate, so an unresolved dependency or a
  config no package ships fails the publish instead of reaching users. The Hub
  surfaces an update the moment the repo db lands, so the test now has to pass
  before the db is published, not after (`.github/workflows/publish-repo.yml`,
  `installation/tests/container-install.sh`).

### Fixed
- **Every build toolchain now installs the full makedepends union of the
  `[ryoku]` packages.** The repo builders (`publish-repo.yml`, the
  `container-install.sh` smoke test, and `install-test.yml`) build with `makepkg
  --nodeps`, so each package's makedepends must be pre-installed; the ISO build
  (`build-iso.yml`) prebuilds the Ryoku.Blobs plugin. `qt6-multimedia` + `ffmpeg`
  (Ryoku.Blobs plays video) and the Hyprland plugin libs were missing across
  them, so `ryoku-blobs` failed `build()` (Qt6 Multimedia not found), the
  compositor plugins failed `prepare()`, and the ISO stage-check failed. All four
  toolchains now install what they build.
- **The publish dependency gate no longer rejects `ryomotion`.** The gate
  `pacman -Si`s every hard dep and skips sibling `[ryoku]` packages via an
  allowlist; `ryomotion` (now a hard dep of `ryoku-desktop`) is a `[ryoku]`
  package but doesn't match the `ryoku*` glob, so the gate searched the official
  repos for it and failed the publish. It's allowlisted now.
- **The camera self-view now hides when recording stops.** The webcam bubble is
  a recording companion, so the shell clears it when the last capture ends (a
  plain mirror toggled on with no recording stays until toggled off).
- **A new Studio recording no longer wipes an open Ryo Motion edit.** `ryomotion`
  (repinned, `pkgrel` 9) reuses the running app for a new clip; it now runs the
  save / discard / cancel dialog before replacing the editor instead of
  force-closing it, so an in-progress edit is never silently lost.
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
