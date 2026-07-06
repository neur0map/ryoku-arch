# Repository structure

Three pillars, one job each. Everything else is documentation or tooling.

- `ryoku/` the desktop that a user runs.
- `system/` the machine the desktop runs on.
- `installation/` how that machine is built.

The golden rule: **every path has one purpose and appears once.** If you need
something that already exists, reference it; do not copy it.

## `ryoku/` the desktop

Deploys into the user's home (`~/.config`, `~/.local/...`) one way. Source of
truth for the live desktop.

- `apps/` one directory per application, holding that app's native config only:
  `kitty/`, `fish/`, `fastfetch/` (plus the `ryoku-fastfetch` launcher), `nvim/`
  (LazyVim), `yazi/`, `starship/`, `nautilus/`, `npm/` (`npmrc`), `pip/`
  (`pip.conf`). `mimeapps.list` sets default apps.
- `hyprland/` the Hyprland config, authored in **Lua**. `hyprland.lua` is the
  entry point and `require`s each module. `keyboard.lua`, `gpu.lua`,
  `monitors.lua` are hardware-managed seeds, and `monitors_user.lua.example` shows
  how to hand-pin a display that autoscale must leave alone; `themes/` holds the
  full-system theme rices Ryoku Settings applies. `modules/` is one concern per file
  (`env`, `input`, `displays`, `decoration`, `animations`, `binds`, `ryoshot`,
  `window_rules`, `fullscreen`, `autostart`). `scripts/` holds the leaf shell helpers the UI
  calls directly: the `ryoku-cmd-*` screen tools (lens, OCR, color, QR, webcam
  mirror, screen record, night light, caffeine) plus the stash and sysinfo
  helpers. `hypridle.conf` is the idle daemon's native config. The whole
  directory deploys to `~/.config/hypr/`.
- `lockscreen/` `qylock/` (the lock theme and its quickshell lockscreen),
  `install-qylock`, and `sddm/` (the greeter setup).
- `shell/` the desktop shell subsystem: `quickshell/` (the QML UI: `pill` (the
  plated top bar and morphing island, which also draws the screen frame, hosts
  the edge popouts under `pill/popouts/`, and grows the centre-island control
  deck (`Super+D`:
  stash, tools, and utilities)), `launcher`, `ryoshot`, and `widgets` (the desktop
  clock and weather on the wallpaper), and `plugins` (the third-party shell
  plugin runtime: `discover.sh` merges the catalogue with the user's
  `plugins.json`, `shell.qml` is the desktop-widget host layer, and `kit/` is the
  `Ryoku.PluginKit` QML module a plugin imports for the signature look; see
  `docs/plugins.md`)),
  `plugin/` (`Ryoku.Blobs`, the C++/QML SDF metaball module the frame renders
  with; `build.sh` builds it, and it ships prebuilt), `wallust/` (palette from
  the wallpaper), `qt6ct/` (the Qt icon theme, `qt6ct.conf`),
  `systemd/` (the user session target), `ipc/` (`ryoku-shell`, the Go shell
  daemon that supervises the Quickshell components, owns wallpaper/clipboard/
  lock and the GNOME keyring password prompt (it registers as the keyring system
  prompter; see `ipc/prompter.go` and `ipc/secretexchange.go`), and serves the
  control socket). `deploy.sh` and `dev-*.sh` are the live
  dev-loop tools.
- `cli/` the user-facing control CLI, one Go program (`ryoku`): `update`,
  `rollback`, `snapshots`, `status`, `materialize` (lay the base configs into
  `~/.config`), and `reload`. It orchestrates pacman, yay, and snapper; it does
  not reimplement them. Per-command reference, user- vs developer-facing, in
  `docs/cli.md`.
- `hub/` Ryoku Settings, the central control-center GUI (`Super + ,`): `backend/`
  (`ryoku-hub`, the Go data plane that reads the keybind legend from the live
  Hyprland config, generates the `settings.lua` override from a JSON document, and
  persists hub state as TOML) and `quickshell/` (the native Qt6/QML app, a
  `FloatingWindow` with a grouped nav rail and global fuzzy search, with live
  editors for displays, appearance, lockscreen, animations, input, keybinds, window and layer
  rules, autostart, environment, the shell, and the desktop widgets). The product is "Ryoku Settings"; the binary and
  config keep the internal `hub` name. Deployed to `~/.config/quickshell/hub`;
  built by the shell's `deploy.sh`.
- `rashin/` Ryoku Rashin, the optional agent OS (off by default): `backend/`
  (`ryoku-rashin`, one Go program that maintains the markdown knowledge vault at
  `~/.local/share/ryoku/rashin/`, serves the embedded dashboard on
  `127.0.0.1:3600`, and bridges the Hermes agent over ACP) with its hand-authored
  web dashboard embedded under `backend/web/` (no build step), and the `rashin`
  terminal command (the same binary under a second name: natural language to a
  ready-to-run command plan on the fish prompt, with a `conf.d/rashin.fish`
  weave). The Hub's `RashinPage.qml` is the control surface (enable, one-click
  Hermes setup, open dashboard); built by the shell's `deploy.sh`. See
  `docs/rashin.md` and `docs/rashin-terminal.md`.
- `assets/` `brand/` the 力 logo and icons, and `wallpapers/` the shipped
  wallpaper set (installs to `~/Pictures/Wallpapers`).

## `system/` the machine

System-level definition installed into the target.

- `boot/` the boot chain: `limine/`, `mkinitcpio/`, `plymouth/`.
- `hardware/` hardware policy and helper scripts (shipped to `/usr/bin` by
  `ryoku-desktop`): `gpu/` (`ryoku-gpu`, `ryoku-gpu-detect`, udev rule),
  `display/` (`ryoku-monitor`), `audio/` (`ryoku-mic`, the mic-gain normalizer),
  `leds/` (`ryoku-leds`, the OpenRGB accent sync), `drivers/` (per-vendor
  `nvidia`/`intel`/`amd`/`vulkan` install scripts), `power/` (`ryoku-hw-laptop`,
  the shared laptop detector; `ryoku-idle`, the laptop-gated `hypridle` launcher).
- `extras/` the helpers behind the Hub's Extras section, shipped to `/usr/bin` by
  `ryoku-desktop`: `ryoku-extras-install` (installs, removes, and reports the
  optional bundles from the `ryoku-extras` catalogue), the `ryoku-pkg-*` routing
  wrappers (repo, AUR, remove, multilib), and `ryoku-cmd-present`.
- `packages/` the package sets: `base.packages` (every machine, pacstrapped),
  `hardware.packages` (per-profile microcode and GPU drivers), `dev.packages`
  (language toolchains, pacstrapped), `aur.packages` (built post-install).

## `installation/` the build

- `tui/` the Go terminal installer. Collects choices, writes the `RYOKU_*`
  contract, and drives the backend.
- `backend/` `ryoku-install` (the orchestrator) and `lib/` (one file per step:
  `preflight`, `disk`, `luks`, `filesystem`, `pacstrap`, `chroot`, `deploy`,
  `drivers`, `bootloader`, `network`, `aur`). It reads `system/packages/`, adds
  the `[ryoku]` package repository, and installs the desktop onto the target.
- `iso/` the archiso profile. `build.sh` bakes the repo payload into the image,
  prebuilds the Go binaries, and runs `mkarchiso`. `profiledef.sh`,
  `packages.x86_64` (live-only set), and `airootfs/` complete the live image.

## The distribution model

- The desktop ships as signed pacman packages from the `[ryoku]` repository
  (`release/packages/`). `ryoku-desktop` is the umbrella: it depends on
  `ryoku-shell`, `ryoku-hub`, `ryoku-rashin`, `ryoku`, `ryoku-blobs`, and
  `ryoku-keyring`, and lays the base config under `/usr/share/ryoku/config`.
- The installer adds the `[ryoku]` repo, imports the keyring, and installs
  `ryoku-desktop`; per-user config is then copied into `~/.config` by
  `ryoku materialize`, which clobbers Ryoku-owned files and prunes dropped ones
  but never touches user files.
- It only ever flows **repo to system**. A change starts in the repo, is built
  into a package, and is installed; nothing is harvested back from a live machine.

## Shared, not duplicated

When two subsystems need the same thing, it lives once and both reference it:
`ryoku-hw-laptop` is the single laptop/desktop detector used by both GPU policy
and the idle policy. Reuse the helper; never re-implement its logic.

## `ryoku-shell-installer/` the no-ISO installer

The standalone way in: a curl-able `install.sh` bootstrap plus the
`ryoku-shell-install` Go TUI that converts an existing Arch machine into a
Ryoku one: config backup with a generated `restore.sh`, rival-shell and
daemon migration, `[ryoku]` repo trust, the desktop set, SDDM/qylock wiring,
`ryoku materialize`. After it runs once the machine updates through
`ryoku update` like any other. The binary and its checksum are committed so
raw.githubusercontent.com serves them with no release infrastructure.

## `release/` packaging

- `packages/` one directory per pacman package in the `[ryoku]` repo
  (`ryoku-shell`, `ryoku-hub`, `ryoku-rashin`, `ryoku`, `ryoku-blobs`,
  `ryoku-desktop`, `ryoku-keyring`), each a `PKGBUILD` that builds from the
  checked-out monorepo.
- `repo/` builds the signed `[ryoku]` repo from those PKGBUILDs: `build-repo.sh`
  runs `makepkg`, signs every artifact with the release key, and `repo-add`s the
  signed `ryoku.db` into `out/`, laid out exactly as the public mirror serves it.

## Tooling

- `bin/` repo tooling: the release version helpers (`ryoku-release-version`,
  `ryoku-release-bump`) and the CI/hook checks (`ryoku-dev-scan-slop`,
  `ryoku-dev-audit-shell-binds`).
- `tests/` standalone CI check scripts (install chroot-safety, shell tool
  availability).
- `.github/` the workflows and issue/PR templates; `.githooks/` the commit gates.
- `VERSION` the base semver; `.woke.yml` the inclusive-language config.
