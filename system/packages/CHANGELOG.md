# Changelog: system/packages/

## Unreleased

### Added
- `ryoku-extras-install`: installs and removes `nautilus-pack` guests, skips
  `optional`-tier items in a whole-bundle install (they install one at a time),
  and turns an aborted `interactive` fetch into a *deferred* state. Repo installs
  go through `pacman -Syu` (not `-S`), so a bundle can never trigger a partial
  upgrade (a stale library vs a freshly pulled one), and a bundle's `requires`
  (such as `multilib`) is ensured before its packages route.
- `base.packages`: add `ttf-firacode-nerd` and `ttf-hack-nerd`, two popular rice
  nerd fonts, so the shell's Global font picker has more that render on a fresh
  install (JetBrains Mono already ships). The picker also lists other popular
  families and shows whichever ones you install yourself.
- `base.packages`: add `ddcutil`, and `aur.packages`: add `nvibrant-bin`. The
  pill mixer's DISPLAY section drives external-monitor brightness through
  `ddcutil` (DDC/CI) and NVIDIA screen vibrance through `nvibrant`, both
  unguarded and declared nowhere, so on a packaged install those faders were
  silently dead. `ddcutil` ships from `extra`; `nvibrant-bin` is AUR (a no-op on
  non-NVIDIA GPUs). `tests/shell-tool-availability.sh` gained rows for both so
  CI catches the next such gap.
- `aur.packages`: add `mpvpaper`. ryowalls' Live tab plays video wallpapers
  through it (mpv on the background layer), but it was only an optdepend of
  `ryoku-desktop`, so a packaged install never pulled it and live wallpapers never
  worked for users. Listing it in the AUR set the installer installs fixes new
  boxes; `ryoku doctor` points existing ones at `ryoku-pkg-aur-add mpvpaper`.
- `base.packages`: add `wireless-regdb`, so the kernel can load `regulatory.db`.
  Without it the WiFi regulatory domain stays at world `00`, which caps TX power
  (weak uplink, TX rates collapse to the lowest MCS) and disables 6 GHz. The live
  ISO already shipped it, but the installed target set did not, so every install
  booted capped. Kernel-agnostic (shared `/usr/lib/firmware`), so stock `linux`
  and CachyOS kernels are fixed identically.
- `base.packages`: ship the Bluetooth stack, `bluez` + `bluez-utils`. The desktop
  has always had Bluetooth UI (Hub Connections > Bluetooth, the pill's link
  drill-in), but no install ever carried the daemon behind it: org.bluez never
  appeared on the bus, `Quickshell.Bluetooth.defaultAdapter` stayed null, and the
  adapter toggle no-opped silently. bluez-utils ships `bluetoothctl`, which the
  UI's pair-trust-connect flows shell out to. The installer enables
  `bluetooth.service` (see installation/backend).
- `base.packages`: add `nautilus-python`, which runs the Ryoku stash actions
  (Install, Compress, Send with LocalSend) in the Nautilus right-click menu.
- `base.packages`: ship the launcher's three missing tools so its features work
  on a fresh install: `libqalculate` (the calculator's qalc backend for units,
  currency, %, and functions), `mpv-mpris` (exposes the YouTube Music mpv stream
  over MPRIS, so the now-playing card and transport controls work), and `songrec`
  (the Recognize Music action). `tests/shell-tool-availability.sh` now gates all
  three, closing the "feature wired but tool not shipped" gap that let them ship
  broken.
- `base.packages`: add the windowed-VM stack (`qemu-desktop`, `edk2-ovmf`,
  `virglrenderer`) so a VM launches from Ryoku Settings > GPU > Machine out of the
  box. The GPU-passthrough extras (Looking Glass, kvmfr) stay AUR and on demand.
- Cursor themes: ship a curated set of modern XCursor themes the Ryoku Settings
  picker offers, beyond the Bibata family. `base.packages` adds `vimix-cursors`
  (official repo, flat modern); `aur.packages` adds `phinger-cursors` (clean
  rounded, light and dark), `volantes-cursors` (minimal, light and dark),
  `catppuccin-cursors-mocha` (pastel), and `apple_cursor` (macOS style; a source
  build, so best-effort). All install XCursor themes under `/usr/share/icons`, so
  they appear in the picker automatically.
- `base.packages`: add `iw`, used by `ryoku-wifi-powersave` to disable 802.11
  power-save for Game Mode (a low-latency win for competitive play).
- `base.packages`: the curated base set the installer pacstraps.
- `hardware.packages`: per-profile CPU microcode (`[amd]`, `[intel]`). GPU drivers
  come from `system/hardware/drivers/*.sh`, which the installer runs in the target.
- `aur.packages`: AUR add-ons (Limine hooks, Bibata cursors, AUR helper).
- `dev.packages`: the developer toolchains shipped with every machine (Go,
  Node/npm, Rust, Python/pip/pipx, mise).
- `base.packages`: the Ryoku shell runtime (`quickshell`, `awww`, `cliphist`,
  `hyprpicker`, `imagemagick`, `jq`) and the `yazi` file manager. `aur.packages`
  gains `wallust` (palette); `quickshell` moved from AUR to base (now official).
- `aur.packages`: add `localsend-bin` for the AirDrop-style LAN file sharing the
  pill's file stash speaks to. GlazePKG (`gpk`) now ships first-class from the
  `[ryoku]` repo as a `ryoku-desktop` dependency, so it is no longer in the AUR set.
- `base.packages`: add `hypridle` for laptop dim/lock/suspend timeouts and
  `upower` for the shell battery surface.
- `base.packages`: add `openrgb` for wallpaper-driven keyboard and lighting
  color control through `ryoku-leds`.
- `base.packages`: add `noto-fonts-cjk` and `inter-font` so Japanese Ryoku shell
  labels, the 力 brand mark, and the configured UI font render on fresh installs.
- `base.packages`: add `cava` for the pill's separated music visualizer island.
- `base.packages`: add `curl`, `python`, `libnotify`, and `xdg-utils` for the
  pill's file stash (LocalSend LAN discovery and send), weather (wttr.in), and
  opening stashed files with the default app.
- `base.packages`: add `ffmpeg` and `yt-dlp` for the stash's media compress and
  download actions, and `desktop-file-utils` so installing AppImages and tarballs
  refreshes the launcher's desktop database.
- `base.packages`: add `tesseract` and `tesseract-data-eng` for the pill's Super+D
  toolkit OCR (recognize text in a screen region to the clipboard).
- `base.packages`: add `zbar` for the Super+D toolkit QR scanner (decode a QR code
  in a screen region, copy it, and open URLs).
- `base.packages`: add `hyprsunset` for the Super+U utilities night-light toggle
  (a warm screen color temperature), driven by ryoku-cmd-nightlight.
- `base.packages`: add `gpu-screen-recorder` and `wf-recorder` for the pill's
  Super+U utilities Screen Recorder (gpu-screen-recorder, with a wf-recorder
  fallback on multi-GPU machines).
- `aur.packages`: add `handy-bin`, the offline speech-to-text app behind the
  pill's ``Super+` `` voice dictation. It provides `handy`, a normal desktop entry
  (so Handy shows in app search for configuring models), and pulls in
  `gtk-layer-shell`.
- `base.packages`: add `wtype` so Handy types the transcription into the focused
  app on Wayland.
- `base.packages`: add `snap-pac` for automatic pre/post Btrfs snapshots around
  pacman transactions, wired to the snapper `root` config by the installer.

### Fixed
- `hardware.packages`: the `amd-nvidia` profile now pulls `[amd]` + `[intel]`
  microcode. It is offered for an AMD or Intel CPU with an NVIDIA GPU but only
  shipped `amd-ucode`, so an Intel+NVIDIA laptop got the wrong microcode and no
  `intel-ucode`; the mkinitcpio microcode hook keeps only the one matching the
  CPU present, so shipping both is correct on either.
- `base.packages`: ship `papirus-icon-theme`. The shipped Qt icon theme
  (`ryoku/shell/qt6ct/qt6ct.conf`) is `Papirus-Dark`, and `adwaita-icon-theme`
  alone left named freedesktop icons (e.g. `network-wired`, which the Avahi
  desktop entries use) unresolved, since Adwaita carries them only as
  `-symbolic`. With Papirus present the launcher's all-apps grid renders every
  entry's logo instead of a broken-image placeholder.
- `base.packages`: add the desktop session pieces a plain Hyprland needs to render
  and function: `xorg-xwayland`, `hyprpolkit-agent`, `qt6-wayland`, `qt6ct`,
  `xdg-desktop-portal-gtk`, and `adwaita-icon-theme`. Without them the installed
  desktop failed (no Xwayland binary, no polkit agent, unthemed Qt/GTK apps).
- `base.packages`: move the wallpaper daemon `awww` to `aur.packages` as
  `awww-git`. It is AUR-only (upstream renamed swww to awww), so listing it in the
  pacstrapped base set aborted the whole install with "target not found: awww".
- `aur.packages`: switch the cursor theme from the source `bibata-cursor-theme` to
  the prebuilt `bibata-cursor-theme-bin`. Both install the whole Bibata family
  (Modern and Original in Ice, Amber, Classic), but the source build needs
  `python-clickgen` and can fail, which left the Ryoku Settings cursor picker with
  only a fallback theme; the `-bin` package never compiles. The stale comment
  (it claimed XCURSOR_THEME=Bibata-Modern-Classic) now matches the real default,
  Bibata-Modern-Ice.
