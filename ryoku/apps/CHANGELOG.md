# Changelog: ryoku/apps/

## Unreleased

### Added
- `ryovm/`: **SSH sessions no longer break on the terminal type.** Opening SSH
  from kitty (or foot, WezTerm, …) advertised a `TERM` a minimal guest has no
  terminfo for — `clear`, `less`, `vim` died with `'xterm-kitty': unknown
  terminal type`. The command now prefixes `env TERM=xterm-256color` (a real
  binary, so it survives the app's unquoted `$cmd` run — a bare `TERM=` prefix
  was parsed as a command name and failed with exit 127), advertising a
  terminal type every guest ships; the fix is in both the app-opened terminal
  and the copyable command. The wait-for-boot narration also stops crying wolf
  at 60s — a fresh cloud image legitimately takes about a minute to provision
  on first boot (Arch, Fedora), so it reassures instead of warning, and only
  calls it dead after three minutes. Two instant-catalogue fixes rode along:
  Alpine now uses its UEFI cloud image (quickemu boots OVMF; the BIOS variant
  never booted), and the Fedora resolver picks the plain Generic Base qcow2,
  not the UEFI-UKI secure-boot variant. Verified live: Debian, Ubuntu, Arch,
  and Alpine instant machines all ssh in as ryoku with a working terminal
  (`bin/ryovm`, `Singletons/Vm.qml`).
- `ryovm/`: **the instant-machine seed builds with any ISO tool.** genisoimage
  is AUR-only (cdrtools), so a fresh box could not build the cloud-init seed;
  it now uses whatever is present — xorriso (in the Arch repos via
  `libisoburn`), genisoimage, or mkisofs — and `ryovm setup` pulls xorriso
  alongside quickemu so installing the engine also enables instant machines
  (`bin/ryovm`, `ryoku-desktop` optdepend).
- `ryovm/`: **instant machines — a prebuilt VM with a known login, no installer.**
  `ryovm instant <os>` is the Kali/Vagrant model: it fetches a distro's official
  pre-installed cloud qcow2 (Ubuntu, Debian, Fedora, Arch, Alpine, openSUSE,
  Rocky, Alma — the curated catalogue quickget refuses to carry), makes a thin
  copy-on-write overlay so every machine costs ~200 KB until written, and
  attaches a cloud-init `cidata` seed that bakes in the standard **Ryoku burn
  account** — `ryoku`/`ryoku`, the ryovm burn SSH key, passwordless sudo — on
  first boot. No 14-step wizard; ssh-able in under a minute, and every later
  instant of that distro is seconds (overlay + seed + boot, zero download). It
  composes with disposable: a `--disposable` instant discards all writes at
  power-off *including* `/var/lib/cloud`, so every boot is a factory-fresh
  re-provision from the same read-only seed — born configured, dies clean.
  Because a burn machine regenerates its SSH host key each boot, its ssh
  command skips host-key pinning (a throwaway has no identity to verify) while
  installed machines keep their per-VM `known_hosts`. Verified end to end on a
  real Debian 13 cloud image: instant → ssh as `ryoku` (key, no password) →
  passwordless root → disposable re-burn wipes writes and re-creates the
  account (`bin/ryovm`).
- `ryovm/`: **the dispatch board — a full rework of the VM manager.** The window
  reads as a rail-dispatch wall crossed with an instrument panel: split-flap
  cells spell the live state (the header board counts `NN MACHINES · NN
  RUNNING`, every card and the machine stage carry their own drums), each
  machine is a boarding-pass ticket (hanko seal over the real brand mark,
  punched perforation, Fraunces display name, mono manifest grid), subsystems
  report on an annunciator row (KVM/UEFI/TPM/DISK/NET/SSH/SPICE/SEALED/BURN —
  lit means engaged, dark means honestly off), and the destructive verbs live
  under caution-striped guard covers that arm on one click and fire on the
  second. Brand marks come from simple-icons tinted to the board's cream ink
  (one visual system across all ~50 that resolve, Fedora included) with the
  quickemu-icons colour badges as fallback and stamped-initial plates for the
  rest.
- `ryovm/`: **disposable machines.** Set a machine up, hit Seal (one reserved
  qcow2 snapshot + a conf stamp), and every launch with the DISPOSABLE switch
  runs on quickemu's `--status-quo`: all disk writes burn up at power-off and
  the machine boots identical next time — the flaps spell BURNING while it
  runs. A dirtied normal run rolls back under the RESTORE SEAL guard. Proven
  end to end on an installed guest (created files evaporate from disposable
  sessions, survive normal ones, and the seal restore reverts everything).
- `ryovm/`: **USB passthrough per machine.** The detail pane lists the host's
  USB devices with hardware slide-switches; engaged devices write quickemu's
  `usb_devices` array and are handed to the guest at the next boot (engine
  verbs `usb list|set`).
- `ryovm/`: **the library works without the engine.** A missing quickemu is a
  blinking ENGINE OFFLINE banner (with the install action) instead of a locked
  app — importing, configuring and deleting machines never needed it. The
  engine's readiness re-polls every 5s, so the board lights up the moment an
  install finishes. Launch failures, dead-end empty states and every error now
  land on a sticky FAULT row with the full engine output behind a DETAIL
  toggle; commands issued mid-operation queue instead of vanishing; create
  defaults skip dev channels (no more `daily-live` Ubuntu) and prefer vanilla
  editions; Esc dismisses instead of quitting (Ctrl+Q quits, with a handshake
  while a download runs); arrows/Enter drive the library and `/` jumps to
  search; SSH gets a copyable command line, `$TERMINAL` respect, and boot
  honesty end to end: QEMU forwards the guest's port the instant the machine
  starts — long before anything answers — so the board probes for the real
  `SSH-` banner and only lights the SSH lamp and endpoint once the guest can
  actually be reached (until then the field reads "no answer"); the
  click-to-connect window narrates the wait instead of sitting pitch dark on a
  booting guest — where it's going, which account it signs in as, elapsed
  seconds, a live-ISO hint after a quiet minute — then hands over to plain ssh
  the moment the banner lands, holding open on failure with the fix spelled
  out; and the login account rides the detail JSON (`sshUser`), shows in the
  Reach-it command line and is editable in place (`ryovm_ssh_user`), because a
  password prompt for an account that doesn't exist in the guest reads as a
  haunted machine.
- `ryowalls/`: a wallpaper **studio**, not just a browser. A new **Adjust** mode
  (a third tab beside Browse and Tune) shapes the picked wallpaper live in the
  rice preview. For an image: a colour **grade** (brightness, contrast,
  saturation, warmth, vignette) and one-tap **Look** presets (Vivid, Faded,
  Cinematic, Noir, Warm, Cool), baked into a sibling file on Set so the desktop
  matches the preview exactly and the extracted palette follows the edit. For a
  live clip: a **Fill / Fit** control that maps the clip onto the screen through
  `ryoku-livewall` (fill covers, fit letterboxes). Both offer an on-demand
  **Enhance** (AI upscale on the GPU) with a real progress bar and honest phases,
  replacing the buried "Enhance on save" toggle. Enhance leaves a source already
  sharp enough as-is and says so ("Already sharp") instead of faking a pass: an
  image past 4K, or a clip past livewall's decode width where the compositor
  would only downscale the extra detail away. A GPU is chosen by validating its
  real output, not a quick probe (a flaky hybrid dGPU can pass a probe then emit
  black); the H.264 result lands in a new .mp4 beside the source instead of
  overwriting it, and any black run is discarded, so a bad enhance never destroys
  or garbles the original. New `AdjustPanel.qml`,
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
- `ryovm/`: **the app knows whether SSH will answer before you click.** A
  forwarded port is no promise: slirp accepts the TCP connect even while the
  guest is still booting — or is a live ISO that will never run sshd — so
  clicking SSH hung a silent terminal for minutes with no sign of life. The
  engine now probes the actual SSH banner (1s, real signal) and `get` reports
  `sshReady`; the REACH IT panel says "Guest is answering — connect away" in
  green or exactly why not ("still booting, or no SSH server inside — live
  ISOs never have one"), the manifest marks the port "· no answer", the SSH
  annunciator lights only on real readiness, and the interactive attempt is
  bounded at 20s with the diagnosis held on screen instead of an endless
  blank hang (`bin/ryovm`, `VmStage.qml`, `VmDetail.qml`,
  `Singletons/Vm.qml`).
- `ryovm/`: **Stop is a power button, not a hatchet.** `stop` sent quickemu's
  --kill (SIGKILL) straight away: the guest's unflushed writes died with it —
  a machine provisioned seconds before a stop came back missing files — and
  the qcow2 took leaked-cluster damage that had to be repaired on the next
  launch. The engine now presses the ACPI power button over the per-VM QEMU
  monitor socket and gives the guest 20s to shut down clean (a cooperative
  guest takes ~3s); the kill remains as the fallback and as an explicit
  `stop <name> --force`. After a kill it also waits for the dying qemu to
  release the image before returning, and `seal` retries briefly through
  that same lock race instead of failing when asked a breath after a stop
  (`bin/ryovm`).
- `ryovm/`: **the SSH login user is per-machine.** The ssh verb guessed the
  host username for the guest, which is usually wrong; `ryovm_ssh_user` in
  the conf (set with `ryovm config <vm> ryovm_ssh_user <name>`) pins the
  account, with the host name only as the fallback guess (`bin/ryovm`).
- `ryovm/`: **SSH from the app survives more than one machine.** Every VM
  forwards its guest onto the same small host-port range, so the global
  `known_hosts` collided the moment a second machine answered on a port a
  first one once used — ssh failed with "REMOTE HOST IDENTIFICATION HAS
  CHANGED" against your own VM, and the old packaged app's terminal closed
  before the message could be read. The engine's `ssh` verb now pins each
  machine to its own known-hosts file beside its disk with
  `StrictHostKeyChecking=accept-new`: first connect just works, a genuinely
  changed key still fails loudly, and machines can never poison each other
  (`bin/ryovm`). The reworked app already holds the terminal open with the
  diagnosis when the guest refuses.
- `ryovm/`: **the launch and scroll flicker is gone.** Three compounding
  causes: the 5-second poll rebuilt the whole library from a fresh array even
  when nothing changed (every card torn down and re-created, replaying its
  entrance), the entrance animation itself ran from `Component.onCompleted` —
  which also fires for delegates the view creates while scrolling back — and
  the catalogue re-filtered (and so rebuilt all ~92 tiles) on every single
  logo resolution during launch. The engine payloads are now compared before
  they touch a model (identical poll = untouched model, stale detail stays on
  screen until the fresh one lands instead of blinking every det-gated
  section), the roll-call moved to the ListView's populate transition (first
  population only, by design), and the catalogue split no longer depends on
  the icon cache at all (`Singletons/Vm.qml`, `VmGrid.qml`, `OsGrid.qml`).
- `ryowalls/`: **a skipped enhance now explains itself instead of looking dead.**
  The engine's `enhance` prints a one-line JSON verdict on exit (`result`, `kind`,
  the pixels it measured and the cap they met, a `why` on failure), and the panel
  keeps an "Already sharp" or failure note on screen until the pick changes,
  spelling out the numbers ("already 5120px wide — the desktop plays live
  wallpapers at 2560px") instead of flashing a generic label for 3.5 seconds; the
  Enhance button stays through a skip, since the cap moves with the monitor and a
  retry must stay one click away. Failures name their cause (bad GPU output vs. a
  truncated file vs. a missing tool) instead of blaming the GPU for everything.
  The moewalls grid also stopped promising `1280x720` for every clip — the site
  serves previews from 720p to 1440p and dual-wide with no per-item resolution
  anywhere in its API, so a user could pick a tile labelled 720p, hit Enhance on
  the 1440p file it actually downloaded, and read the correct "Already sharp"
  skip as the feature being broken (motionbgs labels were checked against the
  downloaded masters and are honest; wallhaven's come from its API). Local grids
  (Live and Local sources) now badge each clip with its real `ffprobe`d
  resolution — probed 8 at a time so a big pool can't hold the grid hostage —
  and the amber low-res hint covers images too. Also fixed while pinning the
  verdict contract down: an animated webp/gif no longer misreads as past-4K
  (a bare `identify %h` concatenates every frame's height into nonsense like
  "12001200"; the probe now reads the first frame), an unreadable clip no longer
  errexits the verb with no verdict and a state file stuck at "probe" (the user
  saw a GPU blamed for a truncated download), the all-GPUs-failed path no longer
  dies on an unset `ok` under `set -u` before its error verdict prints, a verdict
  from a run that outlived its pick (a download-then-enhance, or minutes of
  frame-by-frame work) reports through the status toast instead of pinning the
  wrong numbers under a wallpaper it never touched, a failed video enhance no
  longer leaves a frozen progress bar under the failure note, and re-enhancing
  within the fade window no longer lets the stale clear-timer blank the status of
  the new run (`bin/ryowalls`, `Singletons/Wallhaven.qml`, `AdjustPanel.qml`,
  `WallCell.qml`; contract pinned by `tests/ryowalls-enhance-verdict.sh`).
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
