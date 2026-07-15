# Ryoku CLI Changelog

## Unreleased

### Added
- **`doctor` keeps the desktop brand off a broken logo image.** brand.json's
  `markImage` override (Ryoku Settings, Shell, Global) wins over the text seal
  everywhere in system chrome, but a moved or unreadable image leaves every
  branded surface empty. A new reconciler clears a dangling `markImage` back to
  the text seal, preserving the chosen name and tint; a no-op when the file is
  absent, the image is unset, or it resolves (`internal/doctor/doctor.go`,
  covered by `TestReconcileBrandLogo`).
- **`doctor` clears a crashed update's stuck progress.** A `ryoku update` that
  dies mid-run (power loss, OOM, a kill) leaves the run-state file in
  "running", so the shell's update island and the Hub keep rendering a phantom
  update for the rest of the session. A new reconciler idles a running/prompt
  run-state with no live `ryoku update` process behind it
  (`internal/doctor/doctor.go`, covered by `TestReconcileStaleUpdateRun`).
- **`doctor` prunes an orphaned `theme.lua`.** Removing the Appearance Themes
  feature left a `~/.config/hypr/theme.lua` on boxes that had a theme applied, and
  `hyprland.lua` no longer loads it. A new reconciler removes the dead file so the
  config dir matches the shipped layout (`internal/doctor/doctor.go`).
- **`ryoku recovery` restores the `wallust` palette generator.** wallust now ships
  from the `[ryoku]` repo as a hard `ryoku-desktop` dependency, so a fresh install
  and `ryoku update` (pacman) already carry it. Recovery now also ensures it
  (`pacman -S --needed wallust` on a box with `[ryoku]` configured, gated on the
  package step so `--no-packages` skips it), so the panic button puts back a
  wallust that an old broken AUR build had dropped and colors follow the wallpaper
  again.
- **`ryoku update` shows real, determinate progress.** The run-state the update
  island and the Hub's Updates page watch now carries the update's ordered
  stages (snapshot, packages, AUR, apply, reload, doctor, finalize), each with
  its own state, the current step's human label, and a live log tail, written
  atomically (temp + rename) so a watcher never reads a half-written file. The
  Hub renders a determinate multi-segment bar and streams the log instead of the
  old fixed progress "wave". On failure the run-state names the step that broke
  and carries the pre-update snapshot id, so the Hub can offer a one-click
  rollback.
- **`ryoku doctor --json`** emits the reconciler findings as a JSON array
  (name, status, detail, remedy): the read-only data seam a GUI System Check can
  render without parsing the human output.
- **`ryoku update` hands itself to the freshly installed binary.** The whole
  update used to run inside the old release's binary, so every fix to
  materialize or the restart flow shipped one release late (the beta-16
  breakage was the old updater deploying the new desktop with old semantics).
  After the pacman step the updater now re-execs `/usr/bin/ryoku update
  --stage2`, so the release being installed also runs its own deploy and
  doctor. If the exec fails it finishes in-process exactly as before.
- **The shell is quiesced while configs swap.** Materialize used to rewrite
  `~/.config/quickshell` under a running quickshell, which hot-reloaded the
  half-copied tree against whatever plugin the old process still had mapped,
  a recipe for glitched and ballooned surfaces right after an update. Stage 2
  now stops the shell daemon (and reaps orphaned `qs` components using the
  real component list; the old one named a `sidebar` that never existed and
  missed `launcher`/`widgets`) before materialize, and starts it after.
- **Rollback snapshots finally appear in the Limine boot menu.** A new
  `limine UKI boot tree` reconciler converges boxes stuck on the flat
  install-time placeholder entry: limine-snapper-sync refuses to hang the
  Snapshots submenu under an entry with no kernel sub-entries, so those boxes
  never showed a rollback at boot no matter how many snapshots snapper kept
  (the design always shipped `ENABLE_UKI=yes` and listed
  limine-mkinitcpio-hook in the AUR set; omarchy works because its installer
  hard-requires that hook). Doctor now installs the hook, whose deploy
  rebuilds the menu as the `/+Ryoku` UKI tree, drops the flat placeholder the
  same way the installer's finalize does, and runs one sync so the snapshots
  show up immediately.
- **New doctor reconcilers for the beta-16 fallout.** `Material Symbols icon
  font` installs the font on boxes that predate it being a package dependency
  (every glyph rendered as its ligature name). `stale dev residue` removes
  home-deployed binaries and QML modules that shadow the packaged install on
  pacman-channel boxes (one old recovery run used to pin the desktop at that
  vintage forever). `shell config schema` migrates a pre-rework
  `~/.config/ryoku/shell.json`: drops the retired island knobs, revives the
  bar they pointed at, and clamps out-of-range frame geometry.
- `ryoku doctor` installs the wallpaper backends (`awww` + `mpvpaper`) when a
  desktop lacks them, instead of only printing the command. Both are AUR, so
  `ryoku update` (pacman) never pulls them: a box that predates them can't set a
  wallpaper, and without mpvpaper a live pick only shows a still frame. `--check`
  just reports what it would add, and the doctor pass at the end of every
  `ryoku update` heals it automatically.
- `ryoku update` offers to install the snapshot helpers when they are missing
  (`snap-pac`, and `limine-snapper-sync` on a Limine system) rather than leaving
  them as a standing `doctor` recommendation. It asks first: a Hub-launched update
  (`RYOKU_UPDATE_UI=hub`) raises the question in the Hub's Updates page and waits
  for the answer; a terminal update asks y/N; a non-interactive run declines. Skip
  or no answer leaves them to `ryoku doctor`, and a failed install never aborts the
  update. The consent rides the existing run-state file (a `prompt` phase plus a
  one-line answer back-channel). Standalone `ryoku doctor` stays recommend-only.
- **Doctor unhijacks the desktop portal routing.** A box migrated from another
  compositor can carry a leftover `~/.config/xdg-desktop-portal/portals.conf`
  (or an `/etc` one), and the portals.conf(5) lookup lets that generic file
  outrank the packaged `hyprland-portals.conf`, so xdg-desktop-portal keeps
  loading the old desktop's backend. With `xdg-desktop-portal-gnome` installed
  (niri's own docs require it) that backend hangs under Hyprland, and every
  app that touches the portal bus at startup (GTK apps read the settings
  portal first thing) waits out a ~25s D-Bus timeout before its window shows:
  "apps are slow to open". Screenshare picks the wrong backend the same way.
  A new `desktop portal routing` reconciler resolves the winning config
  exactly like the portal does, moves every misrouted file aside (kept as
  `.ryoku-bak`), and restarts the portal services. The shell installer has
  moved the user-level file aside since early July; this heals the boxes
  converted before that, and the `/etc` case the installer never handled.

### Changed
- **`doctor`'s wallpaper reconciler now heals only `awww`.** The live (video)
  backend is `ryoku-livewall`, which ships inside the `ryoku-shell` package (the
  `[ryoku]` repo, pulled by `ryoku update`) rather than the AUR, so the
  reconciler no longer installs `phonto`/`mpvpaper` as AUR packages; only the
  image daemon `awww` is still reconciled (`internal/doctor/doctor.go`).
- `doctor`: the `wallpaper daemons` reconciler ensures both live-wallpaper
  backends now (`phonto` for AMD/Intel, `mpvpaper` for NVDEC on NVIDIA) beside
  `awww`, pointing at the one-shot `ryoku-pkg-aur-add`, so a box gets whichever
  its GPU needs (and one from the mpvpaper-only era gains phonto).
- **The CLI is split into focused packages.** The one-package `ryoku` program is
  now a thin dispatcher over `internal/updater` (update, status, rollback,
  channel, run-state, materialize, version), `internal/doctor` (the convergent
  reconcilers, report, and `--explain`), and `internal/sys` (the shared exec,
  package, filesystem, path, and terminal primitives, defined once). `doctor.go`
  no longer holds every reconciler: the limine, hardware, and diagnostic-report
  concerns move to their own files. Behaviour and the command surface (`ryoku
  update`/`doctor`/`status`/...) are unchanged.

### Fixed
- **`ryoku update` on a dev checkout clears "behind" instead of nagging
  forever.** The update fast-forwarded the checkout onto origin/<channel> only
  when the current branch was literally named after the channel (`main`); a dev
  box on `unstable-dev` (or any other branch) skipped the fast-forward and just
  redeployed the same commit, so `deploy.sh` re-recorded the unchanged deployed
  commit and `ryoku status` kept reporting the same commits behind after every
  update. `ryoku update` now fast-forwards any clean checkout that is strictly
  behind the channel onto it, whatever the branch is named (always lossless), so
  updating actually advances the box and the count reaches zero. A branch with
  its own commits (a maintainer mid-dev) or a dirty tree is left untouched and
  redeployed as-is; only the channel branch is still reset onto upstream when it
  has diverged (new `syncChannel`/`isAncestor` in `internal/updater/channel.go`,
  covered by `TestSyncChannel*` and `TestUpdateClearsBehindOnDevBranch`).
- **The Hub's Updates section shows real commit messages on a packaged install,
  not bare package names.** `ryoku status` surfaced the channel's incoming commit
  subjects only on a dev checkout; a packaged box (every ISO or shell install) has
  no checkout, so it fell back to the pacman view and the Hub listed pending
  package names ("ryoku-desktop") under the "INCOMING COMMITS" header, with "N
  commits behind" counting all pending packages. The packaged path now reads the
  running and available commits from the installed and `[ryoku]`-repo
  `ryoku-desktop` versions and lists the commits between them via the public
  GitHub compare API, so a user sees the same commit list a dev box does. The
  lookup is cached by the installed..latest sha pair (a polled status fetches once
  per release) and best-effort: offline or rate-limited, it degrades to a single
  `ryoku-desktop` version-bump row and never hangs the status query. New
  `internal/updater/commits.go` (covered by `commits_test.go`),
  `internal/updater/update.go`, `internal/updater/channel.go`; `RYOKU_REPO_SLUG`
  overrides the repo for a fork.
- **`ryoku update` can no longer run stale home-deployed binaries over the
  freshly materialized configs.** Stage2 resolved `ryoku-shell` (and `ryoku`
  for the doctor step, and `ryoku-rashin`) on PATH, where a past `ryoku
  recovery` or dev deploy in `~/.local/bin` outranks `/usr/bin`, so the update
  quiesced and then relaunched the OLD daemon against the new QML tree -- on
  beta 16 -> 17 that replayed the retired resident wallpaper switcher as an
  endless reopen loop (the stale supervisor respawned the new one-shot
  switcher every time it quit) -- and ran the OLD doctor, whose reconcilers
  predate the release doing the healing. Every self-invocation now prefers the
  packaged `/usr/bin` binary (`pkgBin`; PATH only on package-less checkouts).
  stopShell also quiesces the previously missed `overview` component plus the
  retired `plugins`/`wallpaper` residents (patterns anchored so a user's own
  `qs -c wallpaper...`-named config never matches), and kills the video
  players (`ryoku-livewall`, plus legacy `mpvpaper`/`phonto`) so no orphan
  from the old release survives the swap (`internal/updater/update.go`).
- **`doctor` clears every home-deployed binary shadowing a packaged one, not
  just four.** The dev-residue reconciler's fixed name list missed
  `ryoku-livewall`, the hardware helpers, and the app bins deploy.sh installs,
  leaving a stale player and stale tools pinning every later update. It now
  scans `~/.local/bin` and treats any entry whose `/usr/bin` twin is owned by
  a `ryoku*` package as residue; files the packages never shipped are
  untouched, and paths that fail to delete are reported instead of silently
  claimed removed. Doctor's shell-daemon restart also prefers the packaged
  binary on packaged boxes (`internal/doctor/doctor.go`).
- **`rollback` no longer runs a `snapper rollback` that cannot restore the
  system.** Ryoku pins the root subvolume on the kernel cmdline and in fstab
  (`rootflags=subvol=@`), and snapper's rollback works by flipping the btrfs
  default subvolume, which a pinned `subvol=` ignores; limine-snapper-sync's
  own tooling states the layout is "not compatible with 'snapper rollback'".
  So `ryoku rollback <id>` either failed with a cryptic snapper error or
  flipped a default subvolume nothing reads, while the Hub's one-click "Roll
  back" after a failed update inherited the same dead end. The command now
  teaches the supported flow: reboot into the snapshot from the Limine
  Snapshots menu and run `sudo limine-snapper-restore` there (it restores the
  booted snapshot with its matching kernels from the ESP); with no id it still
  lists the snapshots first, and it points at the sync package when the boot
  menu has no snapshots (`internal/updater/update.go`, `docs/cli.md`).
- **`doctor` respects an install-time "no snapshots" choice.** The snapper
  reconciler converges every btrfs root missing the snapper config onto the
  canonical layout, which silently re-enabled snapshots (creating the
  /.snapshots subvolume and config) on the first update after a user declined
  them in the installer. The installer now records the opt-out as
  `/etc/ryoku/snapshots-disabled`, and the reconciler reads it: marker present
  and no config, snapshots stay off with an explanatory ok (delete the marker
  and run `ryoku doctor` to enable); an existing config always wins over a
  stale marker. Installs that predate the marker keep the old converging
  behavior (`internal/doctor/doctor.go`, covered in `TestPlanSnapper`).
- `update` no longer points a failed `pacman -Syu` at `ryoku rollback` when the
  pre-update snapshot it needs was skipped. Snapshots are best-effort (no
  snapper, no root config), and `snapperPre` then returns empty; the failure
  message still advertised a rollback that had nothing to restore. The hint now
  names the actual pre snapshot when one exists, and says to recover with
  pacman directly when none does (`internal/updater/update.go`).
- **`materialize` guarantees `~/.config/ryoku` exists.** The shell's JSON
  stores (shell.json, launcher.json, hypr.json) live there, but the package
  ships no file under it and the shell's QML self-seed cannot create parent
  directories, so on a box where nothing had written a setting yet the seeds
  failed silently. Materialize now creates the directory at install and on
  every update (`internal/updater/materialize.go`).
- **A stale pacman lock no longer fails `ryoku update`.** A `db.lck` left by a
  crashed pacman made `pacman -Syu` abort, and the fix (doctor's stale-lock
  repair) only ran later in the same update it had just failed. The updater now
  runs that repair right before `pacman -Syu`: an in-use lock (a pacman
  actually running) is left alone, a stateless leftover is removed
  (`internal/updater/update.go`).
- **Doctor heals the boot-menu countdown loop.** On boxes where
  limine-mkinitcpio-hook 1.37+ adopted the `/Ryoku Linux` placeholder as the
  menu directory, the flat placeholder's boot stanza
  (`protocol`/`kernel_path`/`cmdline`/`module_path`) stayed wedged under the
  directory title, where Limine allows only a `comment`. A directory that is
  also a boot entry cannot autoboot: `default_entry` resolved to nothing
  bootable and the timeout restarted forever until an entry was selected by
  hand. The `limine boot menu layout` reconciler now recognises the adopted
  tree (not just the standalone `/+Ryoku` shape) and strips that stanza,
  leaving a clean directory that autoboots.
- **Materialize converges `~/.config/quickshell` against the shipped tree.**
  Pruning used to rely entirely on the recorded manifest, so a box whose state
  file was missing or stale (a lost state dir, an old `deploy.sh` or recovery
  run) kept every QML file a release had dropped, sitting live next to the new
  tree forever. The quickshell dir is wholly Ryoku-owned, so materialize now
  sweeps anything there the package does not ship; other dirs are mixed with
  user files and stay manifest-pruned.
- **`ryoku doctor --check` no longer edits the Hyprland config.** The
  follow-mouse check shelled out to `ryoku-hub hypr get`, which rewrites
  `settings.lua`/`theme.lua` as a side effect, breaking the read-only contract
  of `--check`/`--report`. The check now reads `~/.config/ryoku/hypr.json`
  directly; only the fix path goes through the hub.
- **`ryoku recovery` keeps packaged boxes on the pacman channel.** The rescue
  deploys from a fresh checkout, and that deploy recorded the checkout as the
  update channel: a packaged box that ran recovery silently stopped getting
  `pacman -Syu` through `ryoku update` and tracked raw main tip forever. On a
  box where `ryoku-desktop` is installed, recovery now clears the channel
  record after deploying, and the next update's doctor removes the leftover
  home artifacts once the packages are current.
- **`ryoku doctor` heals the update breakage on users' machines.** A new `limine
  snapshot sync` reconciler aligns `TARGET_OS_NAME` in `/etc/default/limine` with
  the actual Ryoku boot entry name, so `limine-snapper-sync` finds it,
  `snapper-cleanup.service` stops failing on every run, and the boot menu's
  rollback Snapshots submenu syncs again. It reads the real entry name (the
  `/+Ryoku` UKI tree is "Ryoku", a flat fallback is "Ryoku Linux") and converges
  to it, so a healthy box is a no-op and a healthy name is never re-pointed. A new
  `wallpaper daemons` reconciler flags a box missing `awww`/`swww` or `mpvpaper`
  and points at the one-shot `ryoku-pkg-aur-add`, so ryowalls' image and Live tabs
  come back.
- **`ryoku doctor` stops nagging every update about things it cannot fix.**
  Orphaned packages and the hybrid-GPU backlight advisory are now `note`s: shown
  in `ryoku doctor --verbose` and the shared report, silent on a plain run and
  inside `ryoku update`, so a healthy box's update ends quiet. A new `--verbose`
  (`-v`) lists the passing checks and the notes.
- `ryoku update` no longer resets the terminal palette to the shipped default.
  wallust writes the wallpaper-derived colours to `kitty/current-theme.conf`, but
  `materialize` reclobbers every shipped config on each update, so kitty snapped
  back to the "Ryoku dark" seed until you reapplied the wallpaper. it is now a
  seed like the fastfetch readout: laid down once on a fresh install, then left to
  whatever wallust last wrote. the shell widgets and window borders never had this
  problem, they read the palette from `~/.cache/wallust`, which the update leaves
  alone.
- `doctor` restores follow-mouse to the intended default on boxes seeded before
  it changed. The hub default moved from 1 ("Normal", keyboard focus chases the
  cursor) to 2 ("Loose", focus detached from the pointer), but an existing
  `~/.config/ryoku/hypr.json` kept the old 1 baked in, so the generated
  settings.lua pinned `follow_mouse = 1` over the base module's 2 and keyboard
  focus followed the mouse (the "cursor issue" seen around the launcher and pill).
  A one-time reconciler bumps a still-default 1 to 2 and regenerates settings.lua,
  then records a marker so re-picking "Normal" in Settings afterward is left alone.
- `ryoku update` no longer overwrites a customized fastfetch readout. `materialize`
  clobbers every shipped config on each update by design; a user's own edits are
  meant to live in a separate override file it never touches (kitty `user.conf`,
  hypr `user.lua`). fastfetch reads a single config with no include, so editing
  `fastfetch/config.jsonc` directly was the only way to customize the readout, and
  the update wiped it out every time. it is now a seed (like `hypr/keyboard.lua`):
  laid down once on a fresh install, never clobbered after. the emblem it draws
  stays managed so the logo keeps updating, and `doctor` still restores it, so the
  Arch-logo fallback does not come back.
- `doctor` no longer deletes a machine's only UEFI boot entry, and restores one
  that already went missing (the "after a `ryoku update` the boot option is gone,
  not even in the BIOS" report). The "limine boot menu layout" migration retired
  the legacy hand-copied `\EFI\limine\limine.efi` NVRAM entry whenever
  `limine_x64.efi` existed, but on a box without `limine-install` it wrote that
  binary and then removed the entry with nothing registered in its place, so the
  machine dropped off the firmware boot menu entirely and could not boot. The
  migration now retires the old entry only once a replacement is present:
  `limine-install` when it exists, else the installer's own
  `efibootmgr --create ... --loader \EFI\limine\limine_x64.efi`, and it leaves
  the working legacy entry alone if neither can. A new "limine boot entry"
  reconciler re-registers a vanished entry on boxes that still start (via the
  removable EFI/BOOT fallback); it recognizes both limine-install's "Limine"
  entry (a VenHw device path, no file path) and the installer's "Ryoku" entry, so
  it never false-fires on a healthy machine. Covered by `doctor_test.go`.
- `doctor` gains a "fastfetch readout emblem" reconciler. The branded terminal
  readout draws a `kitty-direct` logo from an image file; when that file is
  missing fastfetch silently drops to its built-in Arch logo (empty stderr), so
  the terminal greeted with Arch instead of the Ryoku emblem. A redraw renamed
  the emblem and `config.jsonc` now sources it from `~/.config/fastfetch/` (laid
  beside the config by `ryoku materialize`), but a box that updated before that
  shipped points at an emblem it never received. The reconciler restores it from
  the packaged base config tree, the same file materialize lays; it leaves a
  user-customized logo alone, warns to run `ryoku update` on a box whose package
  predates the shipped emblem, and stays idempotent and quiet on a healthy box.
  Covered by `doctor_test.go`.
- `doctor` gains a "limine boot menu layout" reconciler. Earlier installers
  wrote the branded config to `/boot/limine/limine.conf`, a location Limine
  scans BEFORE `/boot/limine.conf` (the only file `limine-entry-tool`
  manages), so the generated UKI entries and the snapper Snapshots submenu
  were shadowed forever: the boot menu stayed frozen at its install-time
  shape. They also hand-copied the bootloader to `EFI/limine/limine.efi`, a
  path no pacman hook refreshes, so the booted binary silently aged while the
  `limine` package moved on (stale, off-looking menu rendering). The
  reconciler merges the shadow's branding into `/boot/limine.conf` (keeping
  every generated entry, foreign entry, and non-branding global), removes the
  shadow, repoints `default_entry` past the `/+Ryoku` directory at the newest
  UKI, re-deploys the binary onto the tool-refreshed
  `EFI/limine/limine_x64.efi` via `limine-install`, retires the stale NVRAM
  entry, and re-syncs the Windows chainload entry. Config first, binary
  second: the box stays bootable at every interruption point. Covered by
  `doctor_test.go`.
- `doctor` now checks that `limine-snapper-sync.service` is *enabled*, not just
  installed: the package alone never syncs a snapshot into the boot menu.
- `doctor` gains an "SDDM greeter theme" reconciler. Picking a lockscreen skin in
  Ryoku Settings copies it into the SDDM greeter dir; a catalogue skin downloaded
  into a 0700 user-owned temp dir was copied verbatim, so the unprivileged `sddm`
  greeter could not read `/usr/share/sddm/themes/ryoku` and SDDM fell back to its
  embedded theme on every boot. The reconciler normalizes that one fixed dir to
  root-owned and world-readable (`a+rX`) when it has drifted, healing boxes that
  picked a skin before the `ryoku-hub` fix. Idempotent and quiet on a healthy box.
  Covered by `doctor_test.go`.
- `ryoku update` reconciles a checkout that diverged from its channel instead of
  dead-ending. A box that ever deployed `unstable-dev` sits on commits
  `origin/main` lacks, so the fast-forward failed and the Hub kept showing the
  same commits as pending after every "Update now". On the channel branch with a
  clean tree it now resets onto `origin/<channel>` (which mirrors upstream and
  holds no local work to keep) and redeploys. Covered by `channel_test.go`.
- `doctor` gains a "stale install crypt mapper" reconciler. ryoku-install opens
  the encrypted root as `/dev/mapper/root`; a run that died after the open, or a
  retry in the same live session, left that name held, so the next
  `cryptsetup open ... root` aborted with "Device root already exists" and a
  reinstall could not proceed. The reconciler closes a `root` crypt node only
  when it is a true orphan (present, not the device backing `/`, and holding no
  mount anywhere), so a normal encrypted box, where `/dev/mapper/root` IS the
  running root, is never touched. The installer self-heals too (see
  `installation/backend`). Covered by `doctor_test.go`.
- `materialize` now seeds `hypr/keyboard.lua` the way it seeds `monitors.lua` and
  `gpu.lua`: laid down only on a fresh install, never clobbered on update. The
  file documents itself as user-owned ("edits here survive Ryoku updates"), but it
  was overwritten back to the `us` default on every `ryoku update`, so anyone with
  several keyboard layouts had to re-add them after each update. Its comment now
  shows the multi-layout syntax (`kb_layout = "us,ru,de,fr"` with a switch key).
  Covered by `materialize_test.go`.
- `doctor` gains a "cursor theme" reconciler: it warns when a Ryoku desktop has no
  Bibata cursor theme and points at `ryoku-pkg-aur-add bibata-cursor-theme-bin`.
  A failed AUR source build, or a dev checkout (which installs no AUR packages),
  could leave the Ryoku Settings cursor picker with a single fallback theme; the
  prebuilt `-bin` package installs the whole Bibata family. Covered by
  `doctor_test.go`.
- `doctor` gains a "display resolution" reconciler that recovers a monitor a
  degraded link left below its available resolution. A cold boot or the
  post-upgrade `hyprctl reload` can briefly leave a DP/HDMI link advertising only
  a fallback mode (e.g. 800x600); Hyprland resolves `monitors.lua`'s `highrr`
  against that list and never re-picks once the link trains, so the panel stays
  low-res until a relogin. The reconciler (run by every `ryoku update` and by
  hand) re-asserts each output's intended mode via `ryoku-monitor settle`,
  respecting an explicit Ryoku Settings resolution and `monitors_user.lua`.
  Covered by `doctor_test.go` and `tests/monitor-profiles.sh`.
- `materialize` now points at `ryoku deploy` when the base config dir is absent,
  instead of failing with a bare `base config dir not found: /usr/share/ryoku/config`.
  That path only exists on a packaged install; on a dev checkout `ryoku deploy` is
  the command, and the error now says so (a set-but-missing `RYOKU_CONFIG_BASE` is
  called out separately).
- `bin/ryoku-recovery` (the `curl | bash` panic button) now always restores the
  stable `main` branch and repairs the broken checkout in place. A machine from
  an old ISO could be stranded on `unstable-dev`: that ISO's `ryoku-update`
  switched the checkout to a release branch, but the rewritten tree ships none of
  its old helper commands (`ryoku-snapshot`, `ryoku-update-perform`), so the
  update self-destructed and every `ryoku` command broke. Recovery could not dig
  the box out because it honored a leaked `RYOKU_CHANNEL` and cloned a fresh
  checkout beside the broken one, leaving it on `unstable-dev`. Recovery now
  hardcodes `main`, force-resets whichever checkout the machine actually has (the
  pre-rewrite one at the data root, or the current `repo/`) to `origin/main` and
  cleans its stale `bin/` scripts, and drops the dangling pre-rewrite
  `~/.local/lib/runtime-env.sh` PATH bridge. Covered by `tests/ryoku-recovery.sh`.
- `doctor` now creates the snapper `root` config when it is missing instead of
  reporting "not configured" as healthy. The snapshot safety net behind every
  `ryoku update` (the pre/post snapshot pair and the Limine rollback entries) was
  set up only by the installer, so a `ryoku deploy` box, an upgrade from an older
  release, or hand drift left a machine with no snapshots and nothing to restore
  them, and `ryoku snapshots` failed with "config 'root' does not exist". On a
  btrfs root `ryoku doctor` now lays down the same layout the installer writes
  (the `/.snapshots` subvolume, `/etc/snapper/configs/root`, `/etc/conf.d/snapper`,
  ownership, the cleanup timer, and limine-snapper-sync), and on a non-btrfs root
  it warns honestly that snapshots are unavailable. `ryoku status` and the
  pre-update note now distinguish "not configured" from an empty snapshot list.
  When a prerequisite is missing (`snapper` itself, or `snap-pac` and
  `limine-snapper-sync`), doctor does not write a config nothing can use: it
  reports the gap and recommends the exact install command instead.
- `status` no longer escalates to `sudo` unless a real terminal is driving it. The
  Hub and the update island poll `ryoku status --json` on a timer with no
  controlling terminal, but the snapshot count shelled out to interactive
  `sudo snapper list`; with no tty the PAM conversation failed, and `pam_faillock`
  counted every failure until the account was locked out of `sudo` even with the
  right password ("it is not taking my sudo password"). The count now runs only
  from a tty, and even then via `sudo -n` (a cached credential, never a prompt), so
  a background poll can never lock the user out. This also unblocks the Hub Updates
  panel, which sat blank on "checked not yet" while the hung `sudo` kept the status
  query from ever returning.
- `materialize` no longer resets a user's display or GPU configuration on update.
  The package ships seeds for `hypr/monitors.lua` (written by `ryoku-monitor`) and
  `hypr/gpu.lua` (written by `ryoku-gpu`); materialize now seeds them only when
  absent and never clobbers or prunes them. `ryoku update` refreshes shipped
  config while leaving every per-machine and user file (settings.lua, theme.lua,
  user.lua, monitors_user.lua, monitors.lua, gpu.lua) exactly as it found it.
- `doctor` backlight remedy no longer recommends `supergfxctl -m Hybrid` when
  that tool is not installed (it is ASUS-specific and absent on most machines, so
  users hit "Unknown command"). The fix now leads with the universal BIOS GPU/MUX
  route and only mentions the `supergfxctl` shortcut when the binary is present.
  This also cleans up `--explain`, which was echoing the bad command from the
  report it is fed.
- `status` bounds the `checkupdates` call (120s) so a slow or stuck update check
  can never hang `ryoku status` -- the data seam the Hub and the update island
  poll for pending updates.
- Ryoku Hub "check for updates" surfaced nothing on a live mirror: `status` read
  only the `[ryoku]` pacman repo and `checkupdates`, neither of which a dev
  checkout has, so commits pushed to `main` never showed. It now reads the git
  channel below.
- `ryoku update` on a dev checkout crashed at "Materializing desktop configs"
  (`base config dir not found: /usr/share/ryoku/config`): it fell through to the
  packaged path. A checkout now always updates through the git channel + deploy.

### Changed
- `status` and `update` track a git **update channel** (`main` for everyone) on a
  Ryoku checkout, the model the Hub and update island were built for. `status`
  reports how far the **deployed commit** (what the machine is running, recorded
  at deploy) is behind `origin/main`, listing the incoming commits (subject +
  bare short hash). The version it shows is the channel's latest commit, a 7-char
  hash matching GitHub, so a commit pushed to the channel shows as an update until
  the machine redeploys onto it. The fetch takes no credential prompt and is
  bounded so it never hangs. `update` brings
  the channel in (fast-forwarding a clean on-channel checkout) and redeploys from
  the checkout. A packaged install has no checkout, so both fall back to the
  `[ryoku]` pacman view. The `--json` seam gains a `channel` field and
  `pendingUpdates` counts the channel's commits. New `channel.go`;
  `ryoku/shell/deploy.sh` records the checkout and the deployed commit;
  `RYOKU_CHANNEL` overrides the branch.
- On a packaged install `status` now reports the running **commit**. The `[ryoku]`
  packages are versioned `<core>.r<count>.g<sha>` (see release/), so `status` reads
  the `g<sha>` out of the installed and available package versions and shows it as
  the version, with the channel, matching the git-checkout view. The Hub and the
  island then show the commit a machine is on instead of a blank or a static
  `0.1.0-3`.

### Added
- `doctor`: a "Hyprland config integrity" reconciler. It validates that the
  runtime-generated Hyprland drop-ins (`monitors.lua`, `gpu.lua`) still parse and,
  in a live session, reads `hyprctl configerrors`. A corrupt drop-in (a crash or a
  GPU reset that fires monitor events can truncate one mid-write) is regenerated
  from live state, or reset to a safe seed, then the config is reloaded -- so a
  desktop wedged in Hyprland's "emergency mode" recovers without a reboot, which
  `reload`/`update` could not do. Hardware-agnostic. `doctor --report` also gains a
  gpu/compositor stability section (vendor-agnostic GPU resets/hangs across recent
  boots, plus compositor coredumps) so a GPU-reset-induced crash is diagnosable.
- `doctor`: convergent reconcilers for stateful drift the package and config
  layers cannot reach, each idempotent (reports `ok`, converges where safe, or
  proposes the exact fix; `--check` previews) and retireable so the set never
  piles up like ordered migrations. `ryoku update` invokes the `ryoku doctor`
  command after it installs the new binary, so it is one command (not a copy
  baked into update) running the reconcilers from the release just installed. The
  batch covers swap-out-of-snapshots, snapper config consistency, stale pacman
  lock, the `[ryoku]` channel + keyring, desktop session components, the running
  shell daemon (restarted when its control socket is unreachable, so a crashed
  shell with dead keybinds and panels heals itself), failed
  services, btrfs device health, display backlight (no interface, missing
  brightnessctl, or a hybrid-GPU firmware-only backlight that does not dim the
  panel -- read from the kernel's own "no native backlight" verdict, not a sysfs
  value the panel ignores, with the route-to-iGPU fix), pending `.pacnew`, and
  orphaned packages.
- `doctor --report [file]`: when a problem cannot be auto-fixed (or is unknown),
  doctor writes one shareable `.txt` -- the findings plus system state (btrfs
  usage/errors, swaps, failed units, recent journal errors, pacman and ryoku
  channel state, session env) -- and points the user to it, so maintainers have
  the context to diagnose further. Default `~/.local/state/ryoku/doctor-report.txt`;
  no secrets included.
- `doctor --explain`: the reasoning layer over the deterministic reconcilers. It
  sends the diagnostic report to the user's own cloud model (defaults to Groq,
  free; OpenRouter and any OpenAI-compatible endpoint work via `RYOKU_AI_URL`/
  `RYOKU_AI_MODEL`) and prints a root-cause analysis with fix steps, reaching the
  long tail the rules cannot pre-encode. Strictly advisory and read-only: it never
  executes anything (cognition kept separate from actuation), and it is opt-in --
  nothing is sent unless `RYOKU_AI_KEY` (or `~/.config/ryoku/ai-key`) is set.
- `doctor` output is styled for the terminal: colored status glyphs in the Ryoku
  vermilion, terminal-width word-wrap (no more mid-word breaks), and a visible
  `ryoku doctor --explain` hint when issues are found. Color is suppressed when
  the output is piped or `NO_COLOR` is set, so the report file stays plain text.
- `recovery`: a last-resort restore for a broken desktop. It resets a clean
  checkout to `origin/main`, reinstalls the base packages, and rebuilds and
  redeploys the desktop, overwriting the Ryoku configs in `~/.config`. A preflight
  refuses to run on a non-Ryoku machine, and it confirms before touching anything
  (`--yes` skips the prompt, `--no-packages` does configs only). The logic lives
  in the standalone `bin/ryoku-recovery`, which `ryoku recovery` runs from the
  checkout and which doubles as a `curl | bash` rescue when the CLI itself is gone.
- `ryoku` (Go): the user-facing update CLI and single front door to the distro.
  - `update`: snapper pre-snapshot, `pacman -Syu` + `yay`, `materialize`, shell
    reload, snapper post-snapshot. Aborts safely on a package failure.
  - `rollback` / `snapshots`: snapper-backed restore + listing.
  - `status [--json]`: installed/available version, pending updates, snapshot
    count (the `--json` form is the Hub's data seam).
  - `materialize`: lays `/usr/share/ryoku/config` into `~/.config` declaratively --
    copies shipped files, prunes ones dropped from a release, and NEVER touches
    user overrides (`hypr/user.lua`, `kitty/user.conf`, `fish/user.fish`). No
    migrations directory; the production replacement for `deploy.sh`'s config copy.
  - `reload`: delegates to `ryoku-shell reload` (removes the triplicated restart
    logic).
  - `deploy`: DEV-only build-from-checkout loop (RYOKU_REPO).

### Verified
- Builds clean, `go vet` clean. `materialize` tested end to end: copies base
  configs, prunes dropped files, and leaves a user override intact.
- `go test ./...` covers the channel: the deployed-commit baseline, behind counts,
  the commit list, the fast-forward update, and the off-channel/dirty redeploy
  guards. Confirmed live: `ryoku status --json` reports `channel: main` and the
  count goes from 0 to N when `main` advances past the deployed commit.
