# Changelog: ryoku/apps/

## Unreleased

### Added
- `ryowalls/`: a wallpaper **studio**, not just a browser. A new **Adjust** mode
  (a third tab beside Browse and Tune) shapes the picked wallpaper live in the
  rice preview. For an image: a colour **grade** (brightness, contrast,
  saturation, warmth, vignette) and one-tap **Look** presets (Vivid, Faded,
  Cinematic, Noir, Warm, Cool), baked into a sibling file on Set so the desktop
  matches the preview exactly and the extracted palette follows the edit. For a
  live clip: a **Fill / Fit** control that maps the clip onto the screen through
  `ryoku-livewall` (fill covers, fit letterboxes). Both offer an on-demand
  **Enhance** (AI upscale on the GPU) with a real progress bar and honest phases,
  replacing the buried "Enhance on save" toggle; for a live clip Enhance is a
  no-op once the source already meets livewall's decode width, so it never burns
  GPU on detail the compositor would only downscale away. New `AdjustPanel.qml`,
  an `adjust` verb and a reworked on-demand `enhance` verb in the `ryowalls`
  engine, and a `liveFit` setting (`App.qml`, `Singletons/Wallhaven.qml`).
- `ryowalls/`: a **Local** source browses the wallpapers already on the machine,
  images from `~/Pictures/Wallpapers` and live clips from `~/Pictures/livewalls`,
  in one grid with the same All/Images/Live filter the library source uses.
  Setting one is instant (no re-download), and each tile carries a selection
  checkbox so saved wallpapers can be pruned one at a time or in bulk: Select all,
  then Delete behind a confirm. The engine gains `local-list` and a `local-remove`
  that only ever unlinks files under those two folders (`App.qml`, `WallCell.qml`,
  `WallGrid.qml`, `Singletons/Wallhaven.qml`, and the `ryowalls` engine).
- `fish/conf.d/rashin.fish` the terminal weave for Ryoku Rashin's `rashin`
  command: an interactive wrapper that drops a proposed command on the prompt,
  an **Alt+R** binding that transmutes the current command line into a
  command, a `fish_postexec` hook that reports proposed-vs-ran corrections to
  the daemon, and a loader for the generated `rr-<name>` recipe abbreviations.
  Inert when the `ryoku-rashin` daemon is off or absent. Deployed by
  `deploy.sh`, shipped by `ryoku-desktop`. See `docs/rashin-terminal.md`.
- `pipewire/` audio follows the device you just connected. A pipewire-pulse
  drop-in (`pipewire-pulse.conf.d/10-ryoku-switch-on-connect.conf`) loads the
  PulseAudio compat `module-switch-on-connect`, so a Bluetooth headset finishing
  its connect (or a plugged-in USB DAC) becomes the default sink and running
  streams migrate to it. Before, sound kept playing from the old device until
  the sink was re-picked by hand in the mixer. Deployed by `deploy.sh`, shipped
  by `ryoku-desktop`.
- `nautilus/` a Ryoku stash menu in the file-manager right-click: a
  `nautilus-python` extension (`ryoku-stash-menu.py`) that adds **Install with
  Ryoku** (installable files), **Compress with Ryoku** (media), and **Send with
  LocalSend** (a single file), handing the picked file to the control deck's own
  `stash-install.sh` / `stash-compress.sh` and the deck's LocalSend picker so it
  behaves exactly like a stash drop. Install passes `RYOKU_STASH_KEEP=1`, since a
  file you right-clicked is yours to keep, not a redundant stash copy.
- `kitty/` terminal config (`kitty.conf`) plus a default `current-theme.conf` in
  the Ryoku dark palette.
- `fastfetch/` branded readout (`config.jsonc`) and the `ryoku-fastfetch` launcher
  (kitty graphics with a chafa fallback).
- `fish/` shell config with the greeting suppressed and starship, zoxide, fzf,
  and eza wired up.
- `starship/` prompt (directory, git branch, command duration) on a fixed
  Ryoku palette.
- `nautilus/` notes on xdg-user-dirs home folders and optional GSettings defaults.
- `nvim/` LazyVim-based Neovim config with the custom Ryoku startup dashboard
  logo (snacks.nvim header), tokyonight default, plus `ryoku-nvim.desktop` that
  registers it for text files.
- `yazi/` file manager config; its editor opener is Neovim (blocking).
- `mimeapps.list` makes Neovim the default application for text and code files.
- `npm/` ships `~/.npmrc` (global prefix `~/.local`) and `pip/` ships
  `~/.config/pip/pip.conf` (`break-system-packages`), so `npm i -g` and
  `pip install --user` work without root.
- `ryovm/` a virtual-machine manager (`qs -c ryovm`, Super+Shift+V), built on
  quickemu/quickget. A **Library** of your machines and a **Catalog** of ~90
  operating systems (~770 release/edition combos: Windows, macOS, every major
  Linux, the BSDs, Android x86). Brand logos are prefetched in parallel and
  cached to `~/.cache/ryoku/ryovm-icons` (a negative cache skips the ~56 OSes
  with no upstream art, which fall back to a coloured monogram); systems that
  have a real logo sort into a **Popular** section above the rest. Builds a VM in
  app with a live progress bar and Cancel (a `ryovm-fetch` Go helper does the
  parallel download; cancelling wipes the half-image), or from any local ISO via
  **Load ISO**. Manage a machine fully: rename it, pin or leave-automatic its
  cores/memory, **grow** its disk, take and restore **snapshots**, **reclaim**
  the disk (frees the image, keeps the machine) or delete it; every card and the
  detail dossier show the machine's real **disk footprint**, so you can see what
  is eating space. Three display modes: a **Window**, a **SPICE** console, or
  **Headless** (terminal-only, SSH in); the running view shows the mode's
  cursor-release shortcut and the live SPICE/SSH endpoints. The interface wears
  Ryoku's Greek-noir brutalism (flat carbon surfaces, hairlines and hard offset
  shadows, the 力 eyebrow, a Fraunces masthead and registration-mark chrome)
  and tells the truth: automatic resources read **Automatic**, never a
  fabricated number. The `ryovm` engine is the data plane; the GPU-passthrough
  gaming VM in Ryoku Settings > GPU is a separate, single-VM path.

### Changed
- `ryowalls/`: the Live tab plays video wallpapers through **`ryoku-livewall`**
  now, a lightweight software-decode daemon that holds ~40 MB of RAM on any GPU
  vendor, in place of `mpvpaper`/`phonto`, so setting a live wallpaper stays well
  under 100 MB. Browse and select are unchanged; the clip is transcoded to a
  cached <=720p30 clip once, then played. ryowalls still calls `ryoku-shell
  wallpaper set`; the shell's `ipc/wallpaper.go` picks the backend.
- `ryowalls/`: the Adjust tab's live **Max FPS** slider is gone. The wallpaper
  daemon decodes video on the GPU now (phonto/VAAPI or mpv/NVDEC, by GPU) at the
  clip's own rate, so there is no fps cap to tune; the **Fit** control stays and
  maps to the backend's scale/panscan (fill/fit).
- `fastfetch/` new emblem (`assets/brand/fastfetch-emblem.png`), redrawn to say
  what Ryoku is in one mark: a torii gate (the arch, and unmistakably Japanese)
  framing a robed Greek marble philosopher inside a Greek-key meander ring (the
  Greek half, stated twice), a vermillion rising sun, and a 力 hanko seal. The
  old bust read as only-Greek with an ambiguous red circle. Bone line-art on a
  transparent background (no baked backdrop), so it floats on the terminal's
  paper instead of sitting in a box; the sun and seal carry the brand red.
  Generated via fal.ai (recraft vector), recoloured to the brand palette and
  seal-stamped locally.
- `ryowalls/`: the palette tune is now per-image and one-time. Setting a
  wallpaper writes the tune keyed to that image (`ryoku-wallust.json` gains an
  `image` field); the daemon applies it only while that image is the wallpaper,
  and a Super+W cycle takes over with default wallust. Tuning no longer writes a
  global mirror on every change, so a tune can never bleed onto a later
  wallpaper.
- `fish/`: put `~/.local/bin` on `PATH` for every shell (not only interactive),
  so user-installed tools and the `ryoku-fastfetch` wrapper resolve.
- `fastfetch/`: align the readout to the upstream Ryoku config (host/cpu/gpu
  layout, no `title`); the `力` brand logo uses a wider left pad to clear the edge.
- `fastfetch/`: color the keys and percentages with fixed brand truecolor
  instead of palette slots, so the readout stays legible under any wallust theme
  (themed `red`/`green` could fall to near-background contrast and vanish).
- `fish/`: ship a fixed, legible syntax-highlight color scheme set
  unconditionally in `config.fish`. fish applied a palette-tied default theme
  before `config.fish` that rendered typed input in a near-background color
  (invisible as you type); pinning command, param, error, comment, and
  autosuggestion colors keeps the command line readable under any wallust theme.
- `fish/`: hook `cd` into zoxide (`zoxide init fish --cmd cd`), so plain `cd`
  learns and jumps to frecent directories (`cdi` for an interactive pick).
- `yazi/`: show hidden files by default (`[mgr] show_hidden = true`), so dotfile
  trees like `~/.config` are visible.
- `fish/`: route `go install` (`GOBIN`) and `cargo install` (`CARGO_INSTALL_ROOT`)
  to `~/.local/bin` and activate `mise`, so every language tool installs onto
  `PATH` and works from day one.

### Fixed
- `ryowalls/`: **a live wallpaper set from the app no longer reverts on its own.**
  Enhancing a downloaded video ran a detached background job that, minutes later,
  re-issued `wallpaper set` for whatever file it had upscaled, so a clip enhanced
  earlier reclaimed the desktop over a wallpaper you had since chosen. Enhance is
  now an explicit, foreground action that only swaps its result onto the desktop
  when that file is still the live wallpaper (it reads `~/.local/state/ryoku-wallpaper`
  first), so a late finish can never yank an old wallpaper back. Downloads no
  longer auto-enhance, so a plain Set is never followed by a surprise swap.
- `ryowalls/`: "Enhance on save" leaned on the AUR `video2x` for video, which
  builds against system `ncnn` yet is never rebuilt when it changes, so it broke
  the moment Arch's `ncnn` dropped an API it used. Video now upscales frame by
  frame with `ffmpeg` + `waifu2x-ncnn-vulkan`, the same official-repo tool already
  used for images (Arch rebuilds it against `ncnn`), so one reliable tool sharpens
  both. The Install button also did nothing: it ran a bare `gpk <pkg>` (which only
  searches) and lingered until Settings was reopened. It now runs `gpk install` for
  that one tool and re-checks when the window regains focus (`App.qml`,
  `Window.active`), so Install flips to the live toggle on its own.
- `fastfetch/`: the readout fell back to the Arch logo on machines that updated
  (fresh installs were fine). `config.jsonc` now points its emblem at
  `~/.config/fastfetch/fastfetch-emblem.png`, laid beside the config by
  `ryoku materialize`, instead of `~/.local/share/ryoku/assets/brand/`, which is
  seeded only at install time. The emblem redraw above renamed the file, so
  updated machines referenced an emblem they never received and fastfetch
  silently used its built-in Arch logo. See the release changelog for the
  packaging side.
